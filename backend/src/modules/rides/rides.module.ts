import { Module } from '@nestjs/common';
import { RidesController } from './rides.controller';
import { ShareController } from './share.controller';
import { RidesService } from './rides.service';
import { AuthModule } from '../auth/auth.module';
import { PricingModule } from '../pricing/pricing.module';
import { DriversModule } from '../drivers/drivers.module';
import { RealtimeModule } from '../realtime/realtime.module';

@Module({
  imports: [AuthModule, PricingModule, DriversModule, RealtimeModule],
  controllers: [RidesController, ShareController],
  providers: [RidesService],
  exports: [RidesService],
})
export class RidesModule {}