import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';

const AUTO_SUSPEND_THRESHOLD = 3; // 3 complaints → SUSPENDED

@Injectable()
export class SafetyService {
  private readonly log = new Logger('SafetyService');

  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeGateway,
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
    // TODO (Phase 5): also fire SMS via MSG91 to user's emergency contacts.
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
        where: { ride: { driverId: ride.driverId } },
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