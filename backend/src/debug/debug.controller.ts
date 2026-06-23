import { Controller, Get, Post, Req, Body } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import type { Request } from 'express';

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

  // Echo back whatever NestJS sees in the request body. If the
  // body-parser has already lost multi-byte characters, the response
  // will show '?'. If it has not, it will show Hindi.
  @Post('echo')
  echo(@Body() body: unknown, @Req() req: Request) {
    const buf = req.body as Buffer | undefined;
    const bodyAsString =
      typeof buf === 'string'
        ? buf
        : Buffer.isBuffer(buf)
        ? buf.toString('utf-8')
        : JSON.stringify(body);
    return {
      contentType: req.headers['content-type'],
      bodySeenByNest: body,
      rawBodyAsUtf8: bodyAsString,
      bufferLength: Buffer.isBuffer(buf) ? buf.length : null,
      // Show all the ways the bytes could have been encoded so we
      // can see which decoder the framework is using.
      rawBodyAsLatin1: Buffer.isBuffer(buf) ? buf.toString('latin1') : null,
      rawBodyAsHex: Buffer.isBuffer(buf) ? buf.toString('hex') : null,
    };
  }
}
