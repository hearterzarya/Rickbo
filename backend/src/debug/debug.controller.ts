import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

// Debug-only controller to verify whether Hindi text round-trips through
// Prisma + the Neon pooler. Public (no JWT) so we can curl it directly.
//
// NOT meant for production — leave the route in for ops debugging but
// rate-limit / IP-allowlist at the reverse-proxy level if you don't want
// random callers poking at it.
@Controller('debug/utf8')
export class DebugUtf8Controller {
  constructor(private prisma: PrismaService) {}

  @Get()
  async test() {
    const test = 'प्रिया-यात्री';
    // 1. SELECT with a tagged-template parameter (the path the
    //    PrismaService round-trip probe already proved works).
    const q1 = await this.prisma.$queryRaw<{ x: string }[]>`SELECT ${test}::text AS x`;
    // 2. $executeRaw INSERT the same string, then SELECT it back.
    await this.prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS _utf8_probe`);
    await this.prisma.$executeRawUnsafe(`CREATE TEMP TABLE _utf8_probe (t text)`);
    await this.prisma.$executeRaw`INSERT INTO _utf8_probe (t) VALUES (${test}::text)`;
    const q2 = await this.prisma.$queryRaw<{ x: string; len: number }[]>`
      SELECT t AS x, length(t) AS len FROM _utf8_probe
    `;
    return {
      input: test,
      input_length: test.length,
      q1_param_select: q1[0]?.x,
      q1_length: q1[0]?.x?.length,
      q2_after_insert: q2[0]?.x,
      q2_db_length: q2[0]?.len,
    };
  }
}
