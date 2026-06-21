import { Injectable, UnauthorizedException, BadRequestException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { Prisma } from '@prisma/client';

/** Wraps a Prisma operation and converts "RecordNotFound" errors to a 404. */
async function notFoundSafe<T>(fn: () => Promise<T>, what: string): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2025') {
      throw new NotFoundException(`${what} not found`);
    }
    throw e;
  }
}

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  login(username: string, password: string) {
    const adminUser = this.config.get<string>('ADMIN_USERNAME') || 'admin';
    const adminPass = this.config.get<string>('ADMIN_PASSWORD') || 'rickbo-admin';
    if (username !== adminUser || password !== adminPass) {
      throw new UnauthorizedException('गलत username या password');
    }
    const token = this.jwt.sign(
      { sub: 'admin', role: 'admin', username },
      { expiresIn: '12h' },
    );
    return { token, username };
  }

  async stats() {
    const [users, drivers, rides, sosOpen, onlineDrivers] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.driver.count(),
      this.prisma.ride.count(),
      this.prisma.sosEvent.count({ where: { resolved: false } }),
      this.prisma.driver.count({ where: { isOnline: true, status: 'ACTIVE' } }),
    ]);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const ridesToday = await this.prisma.ride.count({
      where: { requestedAt: { gte: today } },
    });
    const completedToday = await this.prisma.ride.count({
      where: { completedAt: { gte: today }, status: 'COMPLETED' },
    });
    const revenueToday = await this.prisma.ride.aggregate({
      _sum: { fare: true },
      where: { completedAt: { gte: today }, status: 'COMPLETED' },
    });
    return {
      users,
      drivers,
      rides,
      ridesToday,
      completedToday,
      revenueToday: revenueToday._sum.fare ?? 0,
      sosOpen,
      onlineDrivers,
    };
  }

  async listRides(opts: { limit?: number; status?: string }) {
    const limit = Math.min(opts.limit ?? 100, 500);
    return this.prisma.ride.findMany({
      where: opts.status ? { status: opts.status as any } : undefined,
      orderBy: { requestedAt: 'desc' },
      take: limit,
      include: { user: true, driver: true, sosEvents: { select: { id: true, resolved: true } } },
    });
  }

  async listDrivers(opts: { limit?: number; status?: string }) {
    const limit = Math.min(opts.limit ?? 200, 500);
    return this.prisma.driver.findMany({
      where: opts.status ? { status: opts.status as any } : undefined,
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        _count: { select: { rides: true } },
      },
    });
  }

  async listUsers(limit = 200) {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 500),
      include: { _count: { select: { rides: true } } },
    });
  }

  async listSos(opts: { resolved?: boolean }) {
    return this.prisma.sosEvent.findMany({
      where: opts.resolved === undefined ? undefined : { resolved: opts.resolved },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        ride: {
          include: {
            user: { select: { phone: true, name: true } },
            driver: { select: { phone: true, name: true, rickshawNumber: true } },
          },
        },
      },
    });
  }

  async resolveSos(id: string, notes?: string) {
    return notFoundSafe(
      () => this.prisma.sosEvent.update({
        where: { id },
        data: { resolved: true, notes: notes ?? 'admin resolved' },
      }),
      'sos event',
    );
  }

  async banDriver(id: string, reason: string) {
    const d = await this.prisma.driver.findUnique({ where: { id } });
    if (!d) throw new NotFoundException('driver not found');
    return notFoundSafe(
      () => this.prisma.driver.update({
        where: { id },
        data: { status: 'BANNED', isOnline: false },
      }),
      'driver',
    );
  }

  async unbanDriver(id: string) {
    return notFoundSafe(
      () => this.prisma.driver.update({
        where: { id },
        data: { status: 'ACTIVE' },
      }),
      'driver',
    );
  }

  async suspendDriver(id: string) {
    return notFoundSafe(
      () => this.prisma.driver.update({
        where: { id },
        data: { status: 'SUSPENDED', isOnline: false },
      }),
      'driver',
    );
  }

  async cancelRide(id: string) {
    return notFoundSafe(
      () => this.prisma.ride.update({
        where: { id },
        data: { status: 'CANCELLED', completedAt: new Date() },
      }),
      'ride',
    );
  }

  async listComplaints() {
    return this.prisma.complaint.findMany({
      orderBy: { id: 'desc' },
      take: 100,
      include: {
        ride: {
          select: {
            id: true,
            user: { select: { phone: true, name: true } },
            driver: { select: { phone: true, name: true, rickshawNumber: true } },
          },
        },
      },
    });
  }

  async resolveComplaint(id: string) {
    return notFoundSafe(
      () => this.prisma.complaint.update({
        where: { id },
        data: { status: 'RESOLVED' },
      }),
      'complaint',
    );
  }
}