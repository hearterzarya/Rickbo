import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import * as admin from 'firebase-admin';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  private getFirebaseApp(): admin.app.App {
    if (admin.apps.length > 0) return admin.apps[0]!;
    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    if (!projectId) throw new BadRequestException('Firebase not configured on server');
    return admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey: this.config.get<string>('FIREBASE_PRIVATE_KEY')?.replace(/\\n/g, '\n'),
        clientEmail: this.config.get<string>('FIREBASE_CLIENT_EMAIL'),
      }),
    });
  }

  // Verify a Firebase ID token (real flow). If the token has no phone_number
  // (anonymous sign-in) we generate a stable placeholder phone so the dev-mode
  // flow still works without configuring Firebase.
  async verify(
    firebaseToken: string,
    role: 'user' | 'driver',
  ): Promise<{ token: string; profile: any; isNew: boolean }> {
    let phone: string;
    try {
      const decoded = await this.getFirebaseApp().auth().verifyIdToken(firebaseToken);
      if (decoded.firebase?.sign_in_provider === 'anonymous' || !decoded.phone_number) {
        phone = `+91test-${decoded.sub.slice(0, 8)}`;
      } else {
        phone = decoded.phone_number;
      }
    } catch (e: any) {
      throw new UnauthorizedException('Firebase token invalid: ' + e.message);
    }
    return this.upsertAndSign(phone, role);
  }

  // Verify a Test OTP login — no Firebase at all. Phone is provided directly.
  async verifyTest(
    phone: string,
    role: 'user' | 'driver',
  ): Promise<{ token: string; profile: any; isNew: boolean }> {
    return this.upsertAndSign(phone, role);
  }

  private async upsertAndSign(phone: string, role: 'user' | 'driver') {
    let profile: any;
    let isNew = false;
    if (role === 'driver') {
      const existing = await this.prisma.driver.findUnique({ where: { phone } });
      if (!existing) {
        profile = await this.prisma.driver.create({
          data: { phone, status: 'ACTIVE' },
        });
        isNew = true;
      } else {
        // Auto-activate on subsequent logins so testing is smooth.
        profile = existing.status === 'PENDING'
          ? await this.prisma.driver.update({ where: { id: existing.id }, data: { status: 'ACTIVE' } })
          : existing;
      }
    } else {
      const existing = await this.prisma.user.findUnique({ where: { phone } });
      if (!existing) {
        profile = await this.prisma.user.create({ data: { phone } });
        isNew = true;
      } else {
        profile = existing;
      }
    }
    const token = this.jwt.sign({ sub: profile.id, phone, role });
    return { token, profile, isNew };
  }
}