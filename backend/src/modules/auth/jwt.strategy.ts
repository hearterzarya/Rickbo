import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

export interface JwtPayload {
  sub: string;   // userId or driverId
  phone: string;
  role: 'user' | 'driver';
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(config: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.get<string>('JWT_SECRET') || 'dev-secret-change-in-prod',
    });
  }

  // Return value is attached to req.user in every guarded route
  async validate(payload: JwtPayload): Promise<JwtPayload> {
    return payload;
  }
}
