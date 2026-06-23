import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    await this.$connect();
    // Sanity-check the session encoding. Railway + PgBouncer sometimes
    // hands us a connection with client_encoding=SQL_ASCII which silently
    // turns Hindi/UTF-8 bytes into '?'. See TROUBLESHOOTING.md.
    try {
      const rows = await this.$queryRaw<{ client_encoding: string; server_encoding: string }[]>`
        SHOW client_encoding;
      `;
      const clientEnc = rows[0]?.client_encoding ?? 'unknown';
      this.logger.log(`Postgres client_encoding=${clientEnc}`);
      if (!/UTF8|UNICODE/i.test(clientEnc)) {
        this.logger.warn(
          `Postgres client_encoding is '${clientEnc}', not UTF-8. ` +
          `Hindi (and other multi-byte) text will be stored as '?'. ` +
          `Add '?client_encoding=UTF8' to DATABASE_URL.`,
        );
      }
    } catch (e) {
      this.logger.warn(`Could not check client_encoding: ${(e as Error).message}`);
    }
  }
}
