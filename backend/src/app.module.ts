import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { DriversModule } from './modules/drivers/drivers.module';
import { RidesModule } from './modules/rides/rides.module';
import { MatchingModule } from './modules/matching/matching.module';
import { PricingModule } from './modules/pricing/pricing.module';
import { SafetyModule } from './modules/safety/safety.module';
import { RealtimeModule } from './modules/realtime/realtime.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    UsersModule,
    DriversModule,
    RidesModule,
    MatchingModule,
    PricingModule,
    SafetyModule,
    RealtimeModule,
  ],
})
export class AppModule {}
