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
      const encRows = await this.$queryRaw<{ client_encoding: string }[]>`
        SHOW client_encoding
      `;
      const dbRows = await this.$queryRaw<{ current_database: string }[]>`
        SELECT current_database() AS current_database
      `;
      const clientEnc = encRows[0]?.client_encoding ?? 'unknown';
      const dbName = dbRows[0]?.current_database ?? '?';
      this.logger.log(`Postgres client_encoding=${clientEnc} db=${dbName}`);
      if (!/UTF8|UNICODE/i.test(clientEnc)) {
        this.logger.warn(
          `Postgres client_encoding is '${clientEnc}', not UTF-8. ` +
          `Hindi (and other multi-byte) text will be stored as '?'. ` +
          `Add '?client_encoding=UTF8&pgbouncer=true' to DATABASE_URL.`,
        );
      }

      // Round-trip test: take a known Hindi string, push it through a
      // SQL cast, read it back. If Postgres or Prisma is doing a lossy
      // conversion, the read-back will differ from the input.
      const test = 'टेस्ट-प्रिया-यात्री';
      const probe = await this.$queryRaw<{ roundtrip: string; length: number }[]>`
        SELECT ${test}::text AS roundtrip, length(${test}::text) AS length
      `;
      const got = probe[0]?.roundtrip ?? '';
      const len = probe[0]?.length ?? 0;
      if (got === test) {
        this.logger.log(
          `UTF-8 roundtrip OK (input=${test.length}ch db.length=${len})`,
        );
      } else {
        this.logger.warn(
          `UTF-8 roundtrip FAILED: input=${JSON.stringify(test)} ` +
          `(${test.length} chars) -> readback=${JSON.stringify(got)} ` +
          `(${len} chars). The lossy layer is between Prisma and the DB.`,
        );
      }
    } catch (e) {
      this.logger.warn(
        `Could not run encoding probe: ${(e as Error).message}`,
      );
    }
  }
}
