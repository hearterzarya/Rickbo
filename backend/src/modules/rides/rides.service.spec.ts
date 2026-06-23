import { RidesService } from './rides.service';
import { PricingService } from '../pricing/pricing.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { DriversService } from '../drivers/drivers.service';

// We test only the DTO-validation / fare-tamper logic by mocking
// PrismaService + PricingService + RealtimeGateway + DriversService.
// (The project has no @nestjs/testing dep — we instantiate RidesService
// directly with a fake DI container.)

describe('RidesService — fare-tamper guard', () => {
  let service: RidesService;

  const mockPricing: any = {
    resolveZone: jest.fn(),
    isValidZone: jest.fn(),
    getFare: jest.fn(),
    isNightNow: jest.fn(),
  };
  const mockPrisma: any = {
    ride: { create: jest.fn(), findUnique: jest.fn(() => Promise.resolve(null)), findFirst: jest.fn(() => Promise.resolve(null)), update: jest.fn() },
    driver: {},
    user: {},
  };
  const mockRealtime: any = {};
  const mockDrivers: any = {};

  beforeEach(() => {
    service = new RidesService(
      mockPrisma as any,
      mockPricing as any,
      mockRealtime as any,
      mockDrivers as any,
    );
    jest.clearAllMocks();
    mockPricing.resolveZone.mockReturnValue('A');
    mockPricing.isValidZone.mockImplementation((z: string) => ['A','B','C','D','E'].includes(z));
    mockPricing.getFare.mockReturnValue(25);
    mockPricing.isNightNow.mockReturnValue(false);
    mockPrisma.ride.create.mockImplementation(async ({ data }: any) => ({
      id: 'ride-1',
      ...data,
      user: {},
    }));
  });

  it('rejects invalid mode', async () => {
    await expect(
      service.create('u1', { mode: 'HITCH' as any, fromZone: 'A', toZone: 'B', pickupLat: 29, pickupLng: 78 }),
    ).rejects.toThrow('mode RESERVE या SHARE होना चाहिए');
  });

  it('rejects passengerCount > 4', async () => {
    await expect(
      service.create('u1', { mode: 'RESERVE', fromZone: 'A', toZone: 'B', pickupLat: 29, pickupLng: 78, passengerCount: 5 }),
    ).rejects.toThrow('1–4 यात्री ही बुक कर सकते हैं');
  });

  it('rejects garbage toZone (tampered)', async () => {
    await expect(
      service.create('u1', { mode: 'RESERVE', fromZone: 'A', toZone: 'Z', pickupLat: 29, pickupLng: 78 }),
    ).rejects.toThrow('गंतव्य ज़ोन सही नहीं है');
  });

  it('rejects SQL-injected toZone strings', async () => {
    await expect(
      service.create('u1', { mode: 'RESERVE', fromZone: 'A', toZone: 'Z_OR_1eq1', pickupLat: 29, pickupLng: 78 }),
    ).rejects.toThrow();
  });

  it('rejects NaN coordinates', async () => {
    await expect(
      service.create('u1', { mode: 'RESERVE', fromZone: 'A', toZone: 'B', pickupLat: NaN, pickupLng: 78 }),
    ).rejects.toThrow('पिकअप की जगह सही नहीं है');
  });

  it('rejects out-of-range coordinates', async () => {
    await expect(
      service.create('u1', { mode: 'RESERVE', fromZone: 'A', toZone: 'B', pickupLat: 200, pickupLng: 78 }),
    ).rejects.toThrow();
  });

  it('passes through valid payload and derives fare on server side', async () => {
    mockPricing.getFare.mockReturnValue(35);
    const ride = await service.create('u1', {
      mode: 'RESERVE', fromZone: 'A', toZone: 'E', pickupLat: 29.6, pickupLng: 78.3,
    });
    expect(ride.fare).toBe(35);
    expect(mockPricing.getFare).toHaveBeenCalledWith('A', 'E', 'reserve', false);
  });

  it('rejects out-of-bounds fare from pricing table', async () => {
    // Pricing returns an absurd value (e.g. tampered table)
    mockPricing.getFare.mockReturnValueOnce(500);
    await expect(
      service.create('u1', { mode: 'RESERVE', fromZone: 'A', toZone: 'E', pickupLat: 29.6, pickupLng: 78.3 }),
    ).rejects.toThrow('किराया सही नहीं निकला');
  });
});
