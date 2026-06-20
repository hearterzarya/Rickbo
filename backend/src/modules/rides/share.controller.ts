import { Controller, Get, Param, Res, NotFoundException } from '@nestjs/common';
import type { Response } from 'express';
import { RidesService } from './rides.service';

// Public — no JWT. Anyone with the share token can see the ride's current status.
// Lives outside the auth-guarded RidesController on purpose.
@Controller('s')
export class ShareController {
  constructor(private rides: RidesService) {}

  @Get(':token')
  async page(@Param('token') token: string, @Res() res: Response) {
    const ride = await this.rides.findByShareToken(token);
    if (!ride) throw new NotFoundException('सवारी नहीं मिली');

    const statusHindi: Record<string, string> = {
      REQUESTED: 'ड्राइवर खोज रहे हैं',
      MATCHED: 'ड्राइवर आ रहा है',
      ARRIVED: 'ड्राइवर पहुँच गए',
      ONGOING: 'सफ़र जारी है',
      COMPLETED: 'सफ़र पूरा हो गया',
      CANCELLED: 'सवारी रद्द हो गई',
    };

    const html = `<!doctype html>
<html lang="hi"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rickbo — सफ़र लाइव</title>
<style>
  body { font-family: system-ui, -apple-system, "Noto Sans Devanagari", sans-serif; margin: 0;
         background: #FFF8E7; color: #1f2937; }
  .wrap { max-width: 420px; margin: 0 auto; padding: 24px; }
  .card { background: #fff; border-radius: 16px; padding: 24px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.08); margin-bottom: 16px; }
  .badge { display: inline-block; background: #16a34a; color: #fff;
           padding: 4px 12px; border-radius: 999px; font-size: 12px; font-weight: 700; }
  h1 { font-size: 24px; margin: 8px 0 4px; }
  .row { display: flex; justify-content: space-between; padding: 8px 0;
         border-bottom: 1px solid #f0f0f0; }
  .row:last-child { border-bottom: 0; }
  .label { color: #6b7280; font-size: 13px; }
  .val { font-weight: 700; font-size: 15px; }
  .footer { text-align: center; color: #9ca3af; font-size: 12px; margin-top: 24px; }
</style></head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="badge">Rickbo • लाइव सफ़र</div>
      <h1>${statusHindi[ride.status] || ride.status}</h1>
      <div class="row"><span class="label">कहाँ से</span><span class="val">${ride.fromZone}</span></div>
      <div class="row"><span class="label">कहाँ तक</span><span class="val">${ride.toZone}</span></div>
      <div class="row"><span class="label">किराया</span><span class="val">₹${ride.fare}</span></div>
      ${ride.driverName ? `
      <div class="row"><span class="label">ड्राइवर</span><span class="val">${ride.driverName}</span></div>
      <div class="row"><span class="label">रिक्शा नंबर</span><span class="val">${ride.rickshawNumber || '—'}</span></div>
      <div class="row"><span class="label">फ़ोन</span><span class="val"><a href="tel:${ride.driverPhone}">${ride.driverPhone}</a></span></div>` : ''}
    </div>
    <div class="footer">Rickbo • नजीबाबाद</div>
  </div>
</body></html>`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(html);
  }
}