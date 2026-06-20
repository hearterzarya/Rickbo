import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async create(data: { phone: string; name?: string }) {
    return this.prisma.user.upsert({
      where: { phone: data.phone },
      update: { name: data.name },
      create: { phone: data.phone, name: data.name },
    });
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByPhone(phone: string) {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  async update(id: string, data: { name?: string; fcmToken?: string; photoUrl?: string }) {
    return this.prisma.user.update({ where: { id }, data });
  }
}