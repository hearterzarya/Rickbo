import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    await this.$connect();
    // Verify the session + server encoding. Some poolers (PgBouncer) can
    // hand out connections whose session state was set by another tenant
    // — most commonly SQL_ASCII — which silently turns Hindi / multi-byte
    // UTF-8 bytes into '?' on insert. See TROUBLESHOOTING.md.
    try {
      const rows = await this.$queryRaw<{
        client_encoding: string;
        server_encoding: string;
        current_database: string;
      }[]>`SHOW client_encoding; SELECT current_database();`;
      const clientEnc = rows[0]?.client_encoding ?? 'unknown';
      this.logger.log(
        `Postgres client_encoding=${clientEnc} server_encoding=${rows[0]?.server_encoding ?? '?'} db=${rows[0]?.current_database ?? '?'}`,
      );
      if (!/UTF8|UNICODE/i.test(clientEnc)) {
        this.logger.warn(
          `Postgres client_encoding is '${clientEnc}', not UTF-8. ` +
          `Hindi (and other multi-byte) text will be stored as '?'. ` +
          `Add '?client_encoding=UTF8&pgbouncer=true' to DATABASE_URL.`,
        );
      }

      // Round-trip test: write a Hindi string, read it back, log the
      // actual bytes. If Postgres or the Prisma decoder is doing a lossy
      // conversion, the read-back will differ from the input.
      const test = 'टेस्ट-प्रिया-यात्री';
      const probe = await this.$queryRaw<{ roundtrip: string; length: number }[]>`
        SELECT ${test}::text AS roundtrip, length(${test}::text) AS length
      `;
      const got = probe[0]?.roundtrip ?? '';
      const len = probe[0]?.length ?? 0;
      if (got === test) {
        this.logger.log(`UTF-8 roundtrip OK (input=${test.length}ch, db.length=${len})`);
      } else {
        this.logger.warn(
          `UTF-8 roundtrip FAILED: input=${test} (${test.length} chars, ${test.length * 3}B) ` +
          `-> readback=${JSON.stringify(got)} (${len} chars). ` +
          `Encoding conversion happening at DB or Prisma layer.`,
        );
      }
    } catch (e) {
      this.logger.warn(`Could not check client_encoding: ${(e as Error).message}`);
    }
  }
}
