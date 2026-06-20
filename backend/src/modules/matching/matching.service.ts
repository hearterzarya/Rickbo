import { Injectable } from '@nestjs/common';
import { DriversService } from '../drivers/drivers.service';

// Phase 2 MVP: matching is performed by RidesService.startMatching (one-by-one offer).
// This service is kept as a thin wrapper so other modules (Phase 4 Share) can extend it.
@Injectable()
export class MatchingService {
  constructor(private drivers: DriversService) {}

  async findNearestDriverId(lat: number, lng: number): Promise<string | null> {
    const nearby = await this.drivers.findNearbyOnlineDrivers(lat, lng);
    return nearby[0]?.id ?? null;
  }
}