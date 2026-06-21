import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { join } from 'path';
import { existsSync } from 'fs';
import * as express from 'express';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors({ origin: '*' });
  // Serve admin dashboard at /admin and /admin/* if the built static folder exists.
  // The admin HTML uses fetch() against /admin/* API routes (handled by AdminController),
  // so we serve the index.html for the SPA root and let the controller handle API paths.
  const adminDir = join(__dirname, '..', 'public', 'admin');
  if (existsSync(adminDir)) {
    // Register raw Express middleware on the underlying express instance.
    // We can't use app.use() / app.get() here because Nest's HTTP adapter
    // treats those as controller routes and tries to resolve providers.
    const expressApp = app.getHttpAdapter().getInstance() as express.Express;
    expressApp.use('/admin', express.static(adminDir, { index: false }));
    // SPA fallback for GET /admin and /admin/ ONLY. API routes like
    // GET /admin/stats, GET /admin/rides, POST /admin/login must NOT be
    // intercepted by the fallback or they'd return HTML instead of JSON.
    const sendIndex = (_req: any, res: any) => {
      res.sendFile(join(adminDir, 'index.html'));
    };
    expressApp.get('/admin', sendIndex);
    expressApp.get('/admin/', sendIndex);
    console.log(`Admin dashboard served at /admin (from ${adminDir})`);
  } else {
    console.log(`Admin static dir not found at ${adminDir} — skipping dashboard`);
  }
  // Railway sets $PORT automatically. Fall back to 4000 for local dev.
  const port = Number(process.env.PORT) || 4000;
  await app.listen(port, '0.0.0.0');
  console.log(`Rickbo backend running on http://0.0.0.0:${port}`);
}
bootstrap();
// refresh trigger
// build marker: Sun Jun 21 12:30:00 IST 2026