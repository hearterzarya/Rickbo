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
    }
    return this.prisma.driver.update({ where: { id }, data: { isOnline: online } });
  }

  // Haversine-based nearest driver search (good enough for a 2km town).
  // PostGIS upgrade can swap this for $queryRaw with ST_DWithin.
  async findNearbyOnlineDrivers(lat: number, lng: number, radiusKm = 5) {
    const drivers = await this.prisma.driver.findMany({
      where: { isOnline: true, status: 'ACTIVE', locationLat: { not: null } },
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