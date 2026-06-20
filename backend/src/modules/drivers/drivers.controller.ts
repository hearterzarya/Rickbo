import { Controller, Post, Get, Patch, Body, UseGuards, Request } from '@nestjs/common';
import { DriversService } from './drivers.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';

@Controller('drivers')
export class DriversController {
  constructor(private drivers: DriversService) {}

  @Post()
  create(@Body() body: { phone: string; name?: string; rickshawNumber?: string }) {
    return this.drivers.create(body);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMe(@Request() req: { user: JwtPayload }) {
    return this.drivers.findById(req.user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  updateMe(
    @Request() req: { user: JwtPayload },
    @Body() body: { name?: string; rickshawNumber?: string; fcmToken?: string },
  ) {
    return this.drivers.update(req.user.sub, body);
  }

  // Must be called before goOnline — spec guardrail
  @UseGuards(JwtAuthGuard)
  @Post('me/location')
  updateLocation(
    @Request() req: { user: JwtPayload },
    @Body() body: { lat: number; lng: number },
  ) {
    return this.drivers.updateLocation(req.user.sub, body.lat, body.lng);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/online')
  goOnline(@Request() req: { user: JwtPayload }) {
    return this.drivers.setOnline(req.user.sub, true);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/offline')
  goOffline(@Request() req: { user: JwtPayload }) {
    return this.drivers.setOnline(req.user.sub, false);
  }
}