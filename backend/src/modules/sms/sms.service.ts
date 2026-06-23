import { Injectable, Logger } from '@nestjs/common';

/**
 * SMS gateway wrapper. Currently MSG91 (matches .env.example).
 *
 * Behaviour:
 *   - If MSG91_API_KEY is missing or still set to the .env placeholder,
 *     sendEmergencySms() logs a warning and returns { sent: false } — the
 *     rest of the SOS flow (DB log + socket alert) still works.
 *   - Real MSG91 call uses the simple /api/sendhttp.php endpoint, which
 *     accepts: authkey, route (4 = transactional), sender, mobiles (comma
 *     separated 91-prefixed numbers), message. URL-encoded.
 *   - Never throws. SMS failures must not break the safety flow.
 */
@Injectable()
export class SmsService {
  private readonly log = new Logger('SmsService');
  private readonly apiKey = process.env.MSG91_API_KEY ?? '';
  private readonly sender = process.env.MSG91_SENDER_ID ?? 'RICKBO';
  private readonly route = process.env.MSG91_ROUTE ?? '4';
  private readonly enabled =
    this.apiKey.length > 0 &&
    !this.apiKey.startsWith('your-');

  async sendEmergencySms(
    toPhone: string,
    raisedBy: 'USER' | 'DRIVER',
    rideId: string,
    lat: number,
    lng: number,
  ): Promise<{ sent: boolean; reason?: string }> {
    if (!this.enabled) {
      this.log.warn(
        `MSG91_API_KEY not configured — skipping emergency SMS to ${toPhone}`,
      );
      return { sent: false, reason: 'no-api-key' };
    }
    const mapsLink =
      lat !== 0 || lng !== 0
        ? `https://maps.google.com/?q=${lat},${lng}`
        : 'location unavailable';
    const message =
      `[Rickbo] SOS raised by ${raisedBy} on ride ${rideId.slice(0, 8)}. ` +
      `Last known location: ${mapsLink}. Please contact them immediately.`;
    const normalized = toPhone.replace(/\D/g, '');
    const mobile = normalized.length === 10 ? `91${normalized}` : normalized;
    const url =
      'https://api.msg91.com/api/sendhttp.php?' +
      new URLSearchParams({
        authkey: this.apiKey,
        mobiles: mobile,
        message,
        sender: this.sender,
        route: this.route,
        country: '91',
      }).toString();
    try {
      const res = await fetch(url, { method: 'GET' });
      const body = await res.text();
      // MSG91 returns a CSV-ish response; 1+ numeric codes are success.
      const ok = res.ok && /^\d/.test(body.trim());
      if (!ok) {
        this.log.error(`MSG91 send failed (status ${res.status}): ${body}`);
        return { sent: false, reason: 'provider-error' };
      }
      this.log.log(`Emergency SMS sent to ${mobile} for ride ${rideId}`);
      return { sent: true };
    } catch (e) {
      this.log.error(`MSG91 send exception: ${(e as Error).message}`);
      return { sent: false, reason: 'exception' };
    }
  }
}