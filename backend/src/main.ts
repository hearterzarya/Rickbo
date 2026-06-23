import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors({ origin: '*' });
  // Admin dashboard is a separate Next.js app at `admin_web/` — no longer
  // bundled into the backend. It talks to /admin/* JSON endpoints over CORS.
  // Railway sets $PORT automatically. Fall back to 4000 for local dev.
  const port = Number(process.env.PORT) || 4000;
  await app.listen(port, '0.0.0.0');
  console.log(`Rickbo backend running on http://0.0.0.0:${port}`);
}
bootstrap();
// build marker: Sun Jun 21 12:30:00 IST 2026