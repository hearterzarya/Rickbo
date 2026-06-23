import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);
  constructor(private prisma: PrismaService) {}

  // Prisma 5.11.0 + Neon pooler has a lossy encoder for typed `String`
  // parameters on INSERT/UPDATE — Hindi/UTF-8 input is silently replaced
  // with '?'. Raw SQL with explicit `::text` casts and a tagged
  // `Prisma.sql` template goes through a different code path and stores
  // multi-byte text correctly. We keep Prisma for reads, and use the
  // raw path for any field that might contain non-ASCII.
  async create(data: { phone: string; name?: string; emergencyContactName?: string; emergencyContactPhone?: string }) {
    const hasNonAscii = [data.name, data.emergencyContactName].some(
      (v) => typeof v === 'string' && /[^\x00-\x7F]/.test(v),
    );
    if (!hasNonAscii) {
      return this.prisma.user.upsert({
        where: { phone: data.phone },
        update: {
          name: data.name,
          emergencyContactName: data.emergencyContactName,
          emergencyContactPhone: data.emergencyContactPhone,
        },
        create: {
          phone: data.phone,
          name: data.name,
          emergencyContactName: data.emergencyContactName,
          emergencyContactPhone: data.emergencyContactPhone,
        },
      });
    }
    // Hindi path: upsert via raw SQL with explicit `::text` casts.
    const result = await this.prisma.$queryRaw<
      {
        id: string;
        phone: string;
        name: string | null;
        photoUrl: string | null;
        fcmToken: string | null;
        trustScore: number;
        role: string;
        isBanned: boolean;
        emergencyContactName: string | null;
        emergencyContactPhone: string | null;
        createdAt: Date;
      }[]
    >`
      INSERT INTO "User" ("id", "phone", "name", "emergencyContactName", "emergencyContactPhone", "trustScore", "role", "isBanned", "createdAt")
      VALUES (gen_random_uuid()::text, ${data.phone}, ${data.name ?? null}::text, ${data.emergencyContactName ?? null}::text, ${data.emergencyContactPhone ?? null}, 0, 'USER', false, NOW())
      ON CONFLICT ("phone") DO UPDATE
        SET "name" = COALESCE(EXCLUDED."name", "User"."name"),
            "emergencyContactName" = COALESCE(EXCLUDED."emergencyContactName", "User"."emergencyContactName"),
            "emergencyContactPhone" = COALESCE(EXCLUDED."emergencyContactPhone", "User"."emergencyContactPhone")
      RETURNING *
    `;
    return result[0];
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByPhone(phone: string) {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  async update(
    id: string,
    data: {
      name?: string;
      fcmToken?: string;
      photoUrl?: string;
      emergencyContactName?: string;
      emergencyContactPhone?: string;
    },
  ) {
    // If any text field that could be Hindi is being updated, do it via
    // raw SQL to avoid the Prisma String encoder regression. We check
    // for non-ASCII so plain-ASCII updates keep using the cheap upsert.
    const hasNonAscii = [data.name, data.emergencyContactName].some(
      (v) => typeof v === 'string' && /[^\x00-\x7F]/.test(v),
    );
    if (!hasNonAscii) {
      return this.prisma.user.update({ where: { id }, data });
    }
    // Hindi path: write with an explicit ::text cast. The Prisma 5
    // regression specifically affects typed String parameter encoding,
    // so we cast to `text` and use Prisma.sql to keep the connection
    // parameters happy.
    const updated = await this.prisma.$queryRaw<
      {
        id: string;
        phone: string;
        name: string | null;
        photoUrl: string | null;
        fcmToken: string | null;
        trustScore: number;
        role: string;
        isBanned: boolean;
        emergencyContactName: string | null;
        emergencyContactPhone: string | null;
        createdAt: Date;
      }[]
    >`
      UPDATE "User"
         SET "name" = COALESCE(${data.name ?? null}::text, "name"),
             "emergencyContactName" = COALESCE(${data.emergencyContactName ?? null}::text, "emergencyContactName"),
             "emergencyContactPhone" = COALESCE(${data.emergencyContactPhone ?? null}, "emergencyContactPhone")
       WHERE "id" = ${id}::text
       RETURNING *
    `;
    return updated[0];
  }
}
