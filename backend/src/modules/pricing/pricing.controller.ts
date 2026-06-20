import { Controller, Get, Query } from '@nestjs/common';
import { PricingService, ZONES } from './pricing.service';

@Controller('pricing')
export class PricingController {
  constructor(private pricing: PricingService) {}

  // GET /pricing/fare?from=A&to=B&mode=reserve&night=false
  @Get('fare')
  getFare(
    @Query('from') from: string,
    @Query('to') to: string,
    @Query('mode') mode: string,
    @Query('night') night: string,
  ) {
    const fare = this.pricing.getFare(from, to, mode ?? 'reserve', night === 'true');
    return { from, to, mode, fare, night: night === 'true' };
  }

  // GET /pricing/zones — list all zones (used by the user app destination picker)
  @Get('zones')
  zones() {
    return ZONES;
  }
}