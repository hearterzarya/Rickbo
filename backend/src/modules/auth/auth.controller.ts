import { Controller, Post, Body, BadRequestException } from '@nestjs/common';
import { AuthService } from './auth.service';

interface TestOtpReq {
  phone: string;          // E.164, e.g. +919876543210
  otp: string;             // 6-digit code
  role: 'user' | 'driver' | 'admin';
}

interface TestOtpStartReq {
  phone: string;
  role: 'user' | 'driver' | 'admin';
}

@Controller('auth')
export class AuthController {
  // In-memory OTP store: phone -> { otp, expiresAt }
  private pending = new Map<string, { otp: string; expiresAt: number }>();

  constructor(private auth: AuthService) {}

  // Real flow: Firebase phone token -> JWT
  @Post('verify')
  verify(@Body() body: { firebaseToken: string; role: 'user' | 'driver' }) {
    return this.auth.verify(body.firebaseToken, body.role ?? 'user');
  }

  // DEV/TEST OTP flow — bypasses Firebase entirely.
  // Step 1: client posts {phone, role} -> server returns a fixed 6-digit OTP.
  // Step 2: client posts {phone, otp, role} -> server returns app JWT.
  @Post('test-otp/start')
  startTestOtp(@Body() body: TestOtpStartReq) {
    if (!body?.phone) throw new BadRequestException('phone चाहिए');
    if (!/^\+?\d{10,15}$/.test(body.phone.replace(/\s/g, ''))) {
      throw new BadRequestException('phone सही नहीं है');
    }
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    this.pending.set(body.phone, {
      otp,
      expiresAt: Date.now() + 5 * 60 * 1000, // 5 min
    });
    // Dev convenience: log the OTP so the developer can read it in the terminal.
    // eslint-disable-next-line no-console
    console.log(`[test-otp] phone=${body.phone} role=${body.role ?? 'user'} otp=${otp}`);
    return { ok: true, devOtp: otp };
  }

  @Post('test-otp/verify')
  async verifyTestOtp(@Body() body: TestOtpReq) {
    if (!body?.phone || !body?.otp) {
      throw new BadRequestException('phone और otp चाहिए');
    }
    const entry = this.pending.get(body.phone);
    if (!entry) throw new BadRequestException('पहले OTP भेजें');
    if (entry.expiresAt < Date.now()) {
      this.pending.delete(body.phone);
      throw new BadRequestException('OTP expire हो गया');
    }
    if (entry.otp !== body.otp) {
      throw new BadRequestException('OTP गलत है');
    }
    this.pending.delete(body.phone);
    return this.auth.verifyTest(body.phone, body.role ?? 'user');
  }

  // ONE-CALL dev login: start + verify in a single round-trip.
  // Uses a FIXED OTP for the demo. Caller still passes phone+role,
  // and we return the JWT directly so an emulator can hit this once and
  // land on home — no need to swap screens and copy an OTP.
  @Post('test-otp')
  async oneCallTestOtp(@Body() body: { phone: string; role: 'user' | 'driver' }) {
    if (!body?.phone) throw new BadRequestException('phone चाहिए');
    if (!/^\+?\d{10,15}$/.test(body.phone.replace(/\s/g, ''))) {
      throw new BadRequestException('phone सही नहीं है');
    }
    return this.auth.verifyTest(body.phone, body.role ?? 'user');
  }
}