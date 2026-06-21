import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

/**
 * Allows the request only if the JWT carries role === 'admin'.
 * Used to gate /admin/* endpoints. The token is signed by the same
 * auth/login flow as user/driver tokens, so admins can log in via
 * the same /auth/test-otp endpoint with role='admin'.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(private jwt: JwtService) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    const auth = req.headers['authorization'] as string | undefined;
    if (!auth || !auth.startsWith('Bearer ')) {
      throw new ForbiddenException('admin token required');
    }
    const token = auth.slice('Bearer '.length).trim();
    try {
      const payload = this.jwt.verify(token) as { role?: string };
      if (payload.role !== 'admin') {
        throw new ForbiddenException('admin role required');
      }
      req.adminPayload = payload;
      return true;
    } catch (e) {
      throw new ForbiddenException('admin token invalid');
    }
  }
}