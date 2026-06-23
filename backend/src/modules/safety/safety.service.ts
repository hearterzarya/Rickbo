import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { SmsService } from '../sms/sms.service';

const AUTO_SUSPEND_THRESHOLD = 3; // 3 complaints → SUSPENDED

@Injectable()
export class SafetyService {
  private readonly log = new Logger('SafetyService');

  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeGateway,
    private sms: SmsService,
  ) {}

  async createSos(data: {
    rideId: string;
    raisedBy: 'USER' | 'DRIVER';
    lat: number;
    lng: number;
    notes?: string;
  }) {
    const ride = await this.prisma.ride.findUnique({ where: { id: data.rideId } });
    if (!ride) throw new NotFoundException('सवारी नहीं मिली');
    const event = await this.prisma.sosEvent.create({ data });
    this.log.warn(`SOS raised on ride ${data.rideId} by ${data.raisedBy}`);
    // Alert the OTHER party via realtime.
    if (data.raisedBy === 'USER' && ride.driverId) {
      this.realtime.emitToDriver(ride.driverId, 'sos:raised', {
        rideId: data.rideId,
        lat: data.lat,
        lng: data.lng,
      });
    } else if (data.raisedBy === 'DRIVER') {
      this.realtime.emitToUser(ride.userId, 'sos:raised', {
        rideId: data.rideId,
        lat: data.lat,
        lng: data.lng,
      });
    }
    // Fire SMS to the SOS-raiser's emergency contact (best-effort, never
    // throws). We notify the raiser's family — the OTHER party is already
    // getting a realtime alert via socket above.
    let contactPhone: string | null | undefined = null;
    if (data.raisedBy === 'USER') {
      contactPhone = (
        await this.prisma.user.findUnique({
          where: { id: ride.userId },
          select: { emergencyContactPhone: true },
        })
      )?.emergencyContactPhone;
    } else if (ride.driverId) {
      // Drivers don't yet have an emergency contact field; fall back to the
      // driver's own phone so the SMS path is exercisable in dev. Phase 5
      // will add Driver.emergencyContactPhone.
      contactPhone = (
        await this.prisma.driver.findUnique({
          where: { id: ride.driverId },
          select: { phone: true },
        })
      )?.phone;
    }
    if (contactPhone) {
      const result = await this.sms.sendEmergencySms(
        contactPhone,
        data.raisedBy,
        data.rideId,
        data.lat,
        data.lng,
      );
      this.log.log(
        `Emergency SMS for ride ${data.rideId}: sent=${result.sent}` +
          (result.reason ? ` reason=${result.reason}` : ''),
      );
    } else {
      this.log.log(
        `No emergency contact on file for ride ${data.rideId} (raisedBy=${data.raisedBy}) — SMS skipped`,
      );
    }
    return event;
  }

  async createRating(data: { rideId: string; by: string; stars: number; comment?: string }) {
    if (data.stars < 1 || data.stars > 5) {
      throw new BadRequestException('Stars 1–5 होने चाहिए');
    }
    const ride = await this.prisma.ride.findUnique({ where: { id: data.rideId } });
    if (!ride) throw new NotFoundException('सवारी नहीं मिली');
    if (ride.status !== 'COMPLETED') {
      throw new BadRequestException('सवारी अभी पूरी नहीं हुई');
    }
    // A ride can be rated by the user (about the driver) AND by the driver (about the user).
    // We track 'by' as a string id — no relationship constraint.
    const rating = await this.prisma.rating.create({ data });
    // Only the user's rating affects driver.ratingAvg.
    if (ride.userId === data.by && ride.driverId) {
      const agg = await this.prisma.rating.aggregate({
        _avg: { stars: true },
        // केवल यात्री → ड्राइवर रेटिंग (driver→user ratings exclude करो)
        where: { ride: { driverId: ride.driverId }, by: { not: ride.driverId } },
      });
      await this.prisma.driver.update({
        where: { id: ride.driverId },
        data: { ratingAvg: agg._avg.stars ?? 0 },
      });
    }
    // Bad user rating (<=2 stars) lowers user trustScore (used in Phase 4+ for matching).
    if (ride.driverId === data.by && ride.userId && data.stars <= 2) {
      await this.prisma.user.update({
        where: { id: ride.userId },
        data: { trustScore: { decrement: 1 } },
      });
    }
    return rating;
  }

  async createComplaint(data: {
    rideId: string;
    against: string;
    reason: string;
    severity?: number;
  }) {
    const ride = await this.prisma.ride.findUnique({ where: { id: data.rideId } });
    if (!ride) throw new NotFoundException('सवारी नहीं मिली');
    const complaint = await this.prisma.complaint.create({ data });
    // Auto-flag repeat offenders — count open complaints against this driver/user.
    // Resolve targetId: if against="driver", use ride.driverId; if "user", use ride.userId.
    const targetId = data.against === 'driver' ? ride.driverId : ride.userId;
    if (!targetId) return complaint;
    const openCount = await this.prisma.complaint.count({
      where: {
        against: data.against,
        rideId: { in: (await this.prisma.ride.findMany({
          where: data.against === 'driver' ? { driverId: targetId } : { userId: targetId },
          select: { id: true },
        })).map((r) => r.id) },
        status: 'OPEN',
      },
    });
    if (openCount >= AUTO_SUSPEND_THRESHOLD && data.against === 'driver') {
      await this.prisma.driver.update({
        where: { id: targetId },
        data: { status: 'SUSPENDED', isOnline: false },
      });
      this.log.warn(`Driver ${targetId} auto-SUSPENDED after ${openCount} complaints`);
    }
    return complaint;
  }

  // Driver-side helper — returns the user ids involved in the last N rides.
  async getTrustScore(userId: string) {
    const u = await this.prisma.user.findUnique({ where: { id: userId } });
    return { userId, trustScore: u?.trustScore ?? 0 };
  }
}