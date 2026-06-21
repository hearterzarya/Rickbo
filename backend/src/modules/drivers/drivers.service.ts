import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class DriversService {
  constructor(private prisma: PrismaService) {}

  async create(data: { phone: string; name?: string; rickshawNumber?: string }) {
    return this.prisma.driver.upsert({
      where: { phone: data.phone },
      update: { name: data.name, rickshawNumber: data.rickshawNumber },
      create: { phone: data.phone, name: data.name, rickshawNumber: data.rickshawNumber, status: 'ACTIVE' },
    });
  }

  async findById(id: string) {
    return this.prisma.driver.findUnique({ where: { id } });
  }

  async findByPhone(phone: string) {
    return this.prisma.driver.findUnique({ where: { phone } });
  }

  async update(id: string, data: { name?: string; rickshawNumber?: string; fcmToken?: string }) {
    return this.prisma.driver.update({ where: { id }, data });
  }

  async updateLocation(id: string, lat: number, lng: number) {
    return this.prisma.driver.update({
      where: { id },
      data: { locationLat: lat, locationLng: lng },
    });
  }

  async setOnline(id: string, online: boolean) {
    if (online) {
      const driver = await this.prisma.driver.findUnique({ where: { id } });
      if (!driver) throw new NotFoundException('Driver नहीं मिला');
      if (!driver.locationLat || !driver.locationLng) {
        throw new BadRequestException('पहले location भेजें — POST /drivers/me/location');
      }
      if (driver.status === 'SUSPENDED' || driver.status === 'BANNED') {
        throw new BadRequestException('Account suspended है');
      }
      // Phase 4: subscription check (CLAUDE.md Section 8 — block if expired)
      if (driver.subscriptionValidUntil && driver.subscriptionValidUntil < new Date()) {
        const days = Math.ceil((Date.now() - driver.subscriptionValidUntil.getTime()) / 86400000);
        throw new BadRequestException(`सब्सक्रिप्शन ${days} दिन पहले ख़त्म हुआ — रिन्यू करें`);
      }
    }
    return this.prisma.driver.update({ where: { id }, data: { isOnline: online } });
  }

  // Phase 4: extend a driver's subscription by N days (admin-only in production).
  async extendSubscription(id: string, days: number) {
    const driver = await this.prisma.driver.findUnique({ where: { id } });
    if (!driver) throw new NotFoundException('Driver नहीं मिला');
    const base = driver.subscriptionValidUntil && driver.subscriptionValidUntil > new Date()
      ? driver.subscriptionValidUntil
      : new Date();
    const newUntil = new Date(base.getTime() + days * 86400000);
    return this.prisma.driver.update({
      where: { id },
      data: { subscriptionValidUntil: newUntil },
    });
  }

  // Haversine-based nearest driver search (good enough for a 2km town).
  // PostGIS upgrade can swap this for $queryRaw with ST_DWithin.
  // Phase 4: also exclude drivers whose subscription has expired.
  async findNearbyOnlineDrivers(lat: number, lng: number, radiusKm = 5) {
    const drivers = await this.prisma.driver.findMany({
      where: {
        isOnline: true,
        status: 'ACTIVE',
        locationLat: { not: null },
        OR: [
          { subscriptionValidUntil: null }, // legacy drivers with no subscription yet
          { subscriptionValidUntil: { gt: new Date() } },
        ],
      },
    });
    return drivers
      .filter((d) =>
        d.locationLat != null && d.locationLng != null &&
        haversineKm(lat, lng, d.locationLat!, d.locationLng!) <= radiusKm,
      )
      .sort((a, b) =>
        haversineKm(lat, lng, a.locationLat!, a.locationLng!) -
        haversineKm(lat, lng, b.locationLat!, b.locationLng!),
      );
  }

  // आज / हफ्ता / महीने का कमाई + सफ़र + औसत रेटिंग (सिर्फ user→driver ratings)
  async getStats(driverId: string, period: 'today' | 'week' | 'month' = 'today') {
    const now = new Date();
    let since: Date;
    if (period === 'today') {
      since = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    } else if (period === 'week') {
      since = new Date(now.getTime() - 7 * 86400000);
    } else {
      since = new Date(now.getTime() - 30 * 86400000);
    }
    const [rides, ratingAgg, totalRidesAgg] = await Promise.all([
      this.prisma.ride.aggregate({
        where: { driverId, status: 'COMPLETED', completedAt: { gte: since } },
        _sum: { fare: true },
        _count: { _all: true },
      }),
      this.prisma.rating.aggregate({
        _avg: { stars: true },
        where: {
          ride: { driverId, completedAt: { gte: since } },
          by: { not: driverId },
        },
      }),
      this.prisma.ride.aggregate({
        where: { driverId, status: 'COMPLETED' },
        _count: { _all: true },
      }),
    ]);
    return {
      rides: rides._count._all ?? 0,
      earnings: rides._sum.fare ?? 0,
      ratingAvg: ratingAgg._avg.stars ?? 0,
      totalRides: totalRidesAgg._count._all ?? 0,
      period,
    };
  }
}

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(deg: number) {
  return (deg * Math.PI) / 180;
}