import { Controller, Post, Get, Patch, Body, UseGuards, Request } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';

@Controller('users')
export class UsersController {
  constructor(private users: UsersService) {}

  @Post()
  create(
    @Body()
    body: {
      phone: string;
      name?: string;
      emergencyContactName?: string;
      emergencyContactPhone?: string;
    },
  ) {
    return this.users.create(body);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMe(@Request() req: { user: JwtPayload }) {
    return this.users.findById(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  updateMe(
    @Request() req: { user: JwtPayload },
    @Body()
    body: {
      name?: string;
      fcmToken?: string;
      photoUrl?: string;
      emergencyContactName?: string;
      emergencyContactPhone?: string;
    },
  ) {
    return this.users.update(req.user.sub, body);
  }
}