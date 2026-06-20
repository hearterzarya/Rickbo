import {
  Controller, Post, Get, Body, Param, UseGuards, Request,
} from '@nestjs/common';
import { RidesService } from './rides.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { JwtPayload } from '../auth/jwt.strategy';

@Controller('rides')
@UseGuards(JwtAuthGuard)
export class RidesController {
  constructor(private rides: RidesService) {}

  @Post()
  create(
    @Request() req: { user: JwtPayload },
    @Body() body: {
      mode: 'RESERVE' | 'SHARE';
      fromZone: string;
      toZone: string;
      pickupLat: number;
      pickupLng: number;
      passengerCount?: number;
    },
  ) {
    if (req.user.role !== 'user') {
      throw new Error('Only passengers can create rides');
    }
    return this.rides.create(req.user.sub, body);
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.rides.findById(id);
  }

  @Post(':id/accept')
  accept(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
  ) {
    if (req.user.role !== 'driver') throw new Error('Only drivers can accept');
    return this.rides.accept(req.user.sub, id);
  }

  @Post(':id/arrive')
  arrive(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
  ) {
    return this.rides.arrive(req.user.sub, id);
  }

  @Post(':id/start')
  start(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
    @Body() body: { otp: string },
  ) {
    return this.rides.start(req.user.sub, id, body.otp);
  }

  @Post(':id/complete')
  complete(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
  ) {
    return this.rides.complete(req.user.sub, id);
  }

  @Post(':id/cancel')
  cancel(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
    @Body() body: { reason?: string },
  ) {
    return this.rides.cancel(req.user.sub, req.user.role, id, body?.reason);
  }
}