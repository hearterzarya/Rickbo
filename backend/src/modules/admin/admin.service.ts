import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  // ─── Stats ──────────────────────────────────────────────────────
  async stats() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const [users, drivers, activeDrivers, ridesToday, openSos, ongoingRides] = await Promise.all([
      this.prisma.user.count({ where: { role: 'USER', isBanned: false } }),
      this.prisma.driver.count(),
      this.prisma.driver.count({ where: { status: 'ACTIVE' } }),
      this.prisma.ride.count({ where: { requestedAt: { gte: today } } }),
      this.prisma.sosEvent.count({ where: { resolved: false } }),
      this.prisma.ride.count({ where: { status: { in: ['MATCHED', 'ONGOING'] } } }),
    ]);
    return { users, drivers, activeDrivers, ridesToday, openSos, ongoingRides };
  }

  // ─── Users ──────────────────────────────────────────────────────
  listUsers() {
    return this.prisma.user.findMany({
      where: { role: 'USER' },
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true, phone: true, name: true, trustScore: true, isBanned: true, createdAt: true,
        _count: { select: { rides: true } },
      },
    });
  }

  async banUser(id: string) {
    const u = await this.prisma.user.findUnique({ where: { id } });
    if (!u) throw new NotFoundException('user not found');
    return this.prisma.user.update({ where: { id }, data: { isBanned: true } });
  }

  async unbanUser(id: string) {
    const u = await this.prisma.user.findUnique({ where: { id } });
    if (!u) throw new NotFoundException('user not found');
    return this.prisma.user.update({ where: { id }, data: { isBanned: false } });
  }

  // ─── Drivers ────────────────────────────────────────────────────
  listDrivers() {
    return this.prisma.driver.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true, phone: true, name: true, rickshawNumber: true,
        aadhaarVerified: true, policeVerified: true,
        status: true, isOnline: true, ratingAvg: true, createdAt: true,
        _count: { select: { rides: true } },
      },
    });
  }

  async approveDriver(id: string) {
    return this.notFoundSafe(
      () => this.prisma.driver.update({ where: { id }, data: { status: 'ACTIVE' } }),
      'driver',
    );
  }

  async suspendDriver(id: string) {
    return this.notFoundSafe(
      () => this.prisma.driver.update({ where: { id }, data: { status: 'SUSPENDED', isOnline: false } }),
      'driver',
    );
  }

  async banDriver(id: string) {
    return this.notFoundSafe(
      () => this.prisma.driver.update({ where: { id }, data: { status: 'BANNED', isOnline: false } }),
      'driver',
    );
  }

  async verifyDriver(id: string, kind: 'aadhaar' | 'police') {
    return this.notFoundSafe(
      () => this.prisma.driver.update({
        where: { id },
        data: kind === 'aadhaar' ? { aadhaarVerified: true } : { policeVerified: true },
      }),
      'driver',
    );
  }

  // ─── Rides ──────────────────────────────────────────────────────
  listRides(status?: string) {
    return this.prisma.ride.findMany({
      where: status ? { status: status as any } : undefined,
      orderBy: { requestedAt: 'desc' },
      take: 100,
      include: {
        user: { select: { id: true, phone: true, name: true } },
        driver: { select: { id: true, phone: true, name: true, rickshawNumber: true } },
      },
    });
  }

  async cancelRide(id: string) {
    return this.notFoundSafe(
      () => this.prisma.ride.update({
        where: { id },
        data: { status: 'CANCELLED', completedAt: new Date() },
      }),
      'ride',
    );
  }

  // ─── SOS ────────────────────────────────────────────────────────
  listSos(resolved?: boolean) {
    return this.prisma.sosEvent.findMany({
      where: resolved === undefined ? undefined : { resolved },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        ride: {
          include: {
            user: { select: { id: true, phone: true, name: true } },
            driver: { select: { id: true, phone: true, name: true, rickshawNumber: true } },
          },
        },
      },
    });
  }

  async resolveSos(id: string, notes?: string) {
    return this.notFoundSafe(
      () => this.prisma.sosEvent.update({
        where: { id },
        data: { resolved: true, notes: notes ?? 'resolved by admin' },
      }),
      'sos event',
    );
  }

  // ─── Zone / fare (read-only for now) ───────────────────────────
  listZones() {
    // Same hardcoded list as the pricing module
    return [
      { id: 'A', name: 'Station / Bus Stand', lat: 29.6039, lng: 78.3365, radius: 500 },
      { id: 'B', name: 'Station Road / Hospital', lat: 29.6089, lng: 78.3363, radius: 450 },
      { id: 'C', name: 'Purana Bazar / Tehsil', lat: 29.6125, lng: 78.3406, radius: 450 },
      { id: 'D', name: 'Nayi Tehsil / Court', lat: 29.6081, lng: 78.3472, radius: 450 },
      { id: 'E', name: 'Kotdwar Road / St Mary', lat: 29.6105, lng: 78.3522, radius: 500 },
    ];
  }

  // ─── Test helpers ─────────────────────────────────────────────
  // For development only. Resets all online status to false so that the
  // next ride create doesn't get blocked by stale online drivers from
  // earlier test runs.
  async resetOnlineDrivers() {
    const result = await this.prisma.driver.updateMany({
      where: { isOnline: true },
      data: { isOnline: false },
    });
    return { driversTakenOffline: result.count };
  }

  // Helper: convert Prisma "RecordNotFound" into a clean 404.
  private async notFoundSafe<T>(fn: () => Promise<T>, what: string): Promise<T> {
    try {
      return await fn();
    } catch (e: any) {
      if (e?.code === 'P2025') throw new NotFoundException(`${what} not found`);
      throw e;
    }
  }
}