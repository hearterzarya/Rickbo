import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { PricingService } from '../pricing/pricing.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { DriversService } from '../drivers/drivers.service';

interface CreateRideDto {
  mode: 'RESERVE' | 'SHARE';
  fromZone: string;
  toZone: string;
  pickupLat: number;
  pickupLng: number;
  passengerCount?: number;
}

@Injectable()
export class RidesService {
  private readonly log = new Logger('RidesService');
  // track which driver was last offered which ride so we don't double-offer
  private offerRound = new Map<string, Set<string>>(); // rideId -> set of driverIds

  constructor(
    private prisma: PrismaService,
    private pricing: PricingService,
    private realtime: RealtimeGateway,
    private drivers: DriversService,
  ) {}

  async create(userId: string, dto: CreateRideDto) {
    const mode = (dto.mode || '').toUpperCase();
    if (mode !== 'RESERVE' && mode !== 'SHARE') {
      throw new BadRequestException('mode RESERVE या SHARE होना चाहिए');
    }
    if (mode === 'RESERVE') {
      const pax = dto.passengerCount ?? 1;
      if (pax < 1 || pax > 4) {
        throw new BadRequestException('1–4 यात्री ही बुक कर सकते हैं');
      }
    }
    const fare = this.pricing.getFare(
      dto.fromZone,
      dto.toZone,
      mode.toLowerCase(),
      this.pricing.isNightNow(),
    );
    // 10-char share token so passengers can send family a live status link.
    const shareToken = randomBytes(8).toString('base64url');
    const ride = await this.prisma.ride.create({
      data: {
        userId,
        mode,
        fromZone: dto.fromZone,
        toZone: dto.toZone,
        pickupLat: dto.pickupLat,
        pickupLng: dto.pickupLng,
        fare,
        passengerCount: dto.passengerCount ?? 1,
        status: 'REQUESTED',
        shareToken,
      },
      include: { user: true },
    });
    this.log.log(`ride ${ride.id} created (user=${userId}, ${dto.fromZone}->${dto.toZone}, ₹${fare})`);
    // Kick off matching asynchronously — don't block the HTTP response.
    setImmediate(() => this.startMatching(ride.id));
    return ride;
  }

  // Send a ride offer to one driver at a time. If no accept in 20s, try next.
  private async startMatching(rideId: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) return;
    const nearby = await this.drivers.findNearbyOnlineDrivers(ride.pickupLat, ride.pickupLng);
    this.offerRound.set(rideId, new Set());
    if (!nearby.length) {
      this.realtime.emitToUser(ride.userId, 'ride:no-driver', { rideId });
      await this.prisma.ride.update({
        where: { id: rideId },
        data: { status: 'CANCELLED' },
      });
      this.log.log(`ride ${rideId} cancelled — no online drivers`);
      return;
    }
    for (const driver of nearby) {
      // Skip if ride was already accepted/cancelled by a previous driver.
      const current = await this.prisma.ride.findUnique({ where: { id: rideId } });
      if (!current || current.status !== 'REQUESTED') {
        this.log.log(`ride ${rideId} no longer REQUESTED; stopping offer loop`);
        return;
      }
      this.offerRound.get(rideId)!.add(driver.id);
      this.realtime.emitToDriver(driver.id, 'ride:offer', {
        rideId: ride.id,
        fromZone: ride.fromZone,
        toZone: ride.toZone,
        fare: ride.fare,
        mode: ride.mode,
        pickupLat: ride.pickupLat,
        pickupLng: ride.pickupLng,
      });
      this.log.log(`ride ${rideId} offered to driver ${driver.id}`);

      const accepted = await this.waitForAcceptOrTimeout(rideId, driver.id, 20_000);
      if (accepted) {
        this.log.log(`ride ${rideId} ACCEPTED by driver ${driver.id}`);
        return;
      }
    }
    // No one accepted
    const final = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (final?.status === 'REQUESTED') {
      await this.prisma.ride.update({
        where: { id: rideId },
        data: { status: 'CANCELLED' },
      });
      this.realtime.emitToUser(ride.userId, 'ride:no-driver', { rideId });
      this.log.log(`ride ${rideId} cancelled — no driver accepted`);
    }
  }

  // Resolve a promise as soon as either the ride is matched to `driverId` or 20s passes.
  private waitForAcceptOrTimeout(rideId: string, driverId: string, ms: number): Promise<boolean> {
    return new Promise(async (resolve) => {
      let settled = false;
      const finish = (val: boolean) => {
        if (settled) return;
        settled = true;
        clearInterval(t);
        resolve(val);
      };
      const t = setInterval(async () => {
        try {
          const r = await this.prisma.ride.findUnique({ where: { id: rideId } });
          if (r && r.driverId === driverId && r.status === 'MATCHED') finish(true);
          else if (r && r.status !== 'REQUESTED') finish(false);
        } catch { /* ignore */ }
      }, 500);
      setTimeout(() => finish(false), ms);
    });
  }

  async accept(driverId: string, rideId: string) {
    return this.prisma.$transaction(async (tx) => {
      const ride = await tx.ride.findUnique({ where: { id: rideId } });
      if (!ride) throw new NotFoundException('सवारी नहीं मिली');
      if (ride.status !== 'REQUESTED') {
        throw new BadRequestException('यह सवारी पहले ही किसी ने ले ली है');
      }
      // 4-digit OTP
      const otp = String(Math.floor(1000 + Math.random() * 9000));
      const driver = await tx.driver.update({
        where: { id: driverId },
        data: { isOnline: true },
      });
      const updated = await tx.ride.update({
        where: { id: rideId },
        data: { driverId, otp, status: 'MATCHED' },
        include: { driver: true, user: true },
      });
      this.realtime.emitToUser(ride.userId, 'ride:matched', {
        rideId: updated.id,
        otp: updated.otp,
        driver: {
          id: updated.driver!.id,
          name: updated.driver!.name,
          phone: updated.driver!.phone,
          rickshawNumber: updated.driver!.rickshawNumber,
          ratingAvg: updated.driver!.ratingAvg,
        },
        fare: updated.fare,
        pickupLat: updated.pickupLat,
        pickupLng: updated.pickupLng,
      });
      this.realtime.emitToDriver(driverId, 'ride:accepted', { rideId: updated.id });
      return updated;
    });
  }

  async arrive(driverId: string, rideId: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride || ride.driverId !== driverId) {
      throw new BadRequestException('यह सवारी आपकी नहीं है');
    }
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: 'ARRIVED' },
    });
    this.realtime.emitToUser(ride.userId, 'ride:arrived', { rideId });
    return updated;
  }

  async start(driverId: string, rideId: string, otp: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride || ride.driverId !== driverId) {
      throw new BadRequestException('यह सवारी आपकी नहीं है');
    }
    if (ride.otp !== otp) {
      throw new BadRequestException('OTP गलत है');
    }
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: 'ONGOING', startedAt: new Date() },
    });
    this.realtime.emitToUser(ride.userId, 'ride:started', { rideId });
    return updated;
  }

  async complete(driverId: string, rideId: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride || ride.driverId !== driverId) {
      throw new BadRequestException('यह सवारी आपकी नहीं है');
    }
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: 'COMPLETED', completedAt: new Date() },
    });
    this.realtime.emitToUser(ride.userId, 'ride:completed', { rideId });
    return updated;
  }

  async cancel(actorId: string, actorRole: 'user' | 'driver', rideId: string, reason?: string) {
    const ride = await this.prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('सवारी नहीं मिली');
    if (actorRole === 'user' && ride.userId !== actorId) {
      throw new BadRequestException('यह सवारी आपकी नहीं है');
    }
    if (actorRole === 'driver' && ride.driverId !== actorId) {
      throw new BadRequestException('यह सवारी आपकी नहीं है');
    }
    if (['COMPLETED', 'CANCELLED'].includes(ride.status)) {
      return ride;
    }
    const updated = await this.prisma.ride.update({
      where: { id: rideId },
      data: { status: 'CANCELLED' },
    });
    const other = actorRole === 'user' ? ride.driverId : ride.userId;
    if (other) {
      if (actorRole === 'user') {
        this.realtime.emitToDriver(other, 'ride:cancelled', { rideId, by: 'user', reason });
      } else {
        this.realtime.emitToUser(other, 'ride:cancelled', { rideId, by: 'driver', reason });
      }
    }
    return updated;
  }

  async findById(id: string) {
    return this.prisma.ride.findUnique({
      where: { id },
      include: { user: true, driver: true },
    });
  }

  // Public — used by /s/:token HTML page; returns sanitized ride snapshot.
  async findByShareToken(token: string) {
    const ride = await this.prisma.ride.findUnique({
      where: { shareToken: token },
      include: { driver: true },
    });
    if (!ride) return null;
    return {
      status: ride.status,
      fromZone: ride.fromZone,
      toZone: ride.toZone,
      fare: ride.fare,
      driverName: ride.driver?.name ?? null,
      driverPhone: ride.driver?.phone ?? null,
      rickshawNumber: ride.driver?.rickshawNumber ?? null,
      startedAt: ride.startedAt,
      completedAt: ride.completedAt,
    };
  }
}