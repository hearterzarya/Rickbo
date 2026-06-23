import { SmsService } from './sms.service';

/**
 * Unit tests for SmsService.sendEmergencySms. We deliberately exercise only
 * the "no API key" branch here — the network branch needs an integration
 * test with a recorded fixture because MSG91 responses are CSV-ish and
 * change with DLT registration status.
 */
describe('SmsService', () => {
  const originalKey = process.env.MSG91_API_KEY;
  const originalSender = process.env.MSG91_SENDER_ID;
  const originalRoute = process.env.MSG91_ROUTE;

  afterEach(() => {
    if (originalKey === undefined) delete process.env.MSG91_API_KEY;
    else process.env.MSG91_API_KEY = originalKey;
    if (originalSender === undefined) delete process.env.MSG91_SENDER_ID;
    else process.env.MSG91_SENDER_ID = originalSender;
    if (originalRoute === undefined) delete process.env.MSG91_ROUTE;
    else process.env.MSG91_ROUTE = originalRoute;
  });

  it('returns sent=false with no-api-key when env is missing', async () => {
    delete process.env.MSG91_API_KEY;
    const svc = new SmsService();
    const res = await svc.sendEmergencySms('9876543210', 'USER', 'ride-123', 29.6, 78.3);
    expect(res.sent).toBe(false);
    expect(res.reason).toBe('no-api-key');
  });

  it('returns sent=false with no-api-key when env is the placeholder', async () => {
    process.env.MSG91_API_KEY = 'your-msg91-api-key';
    const svc = new SmsService();
    const res = await svc.sendEmergencySms('9876543210', 'DRIVER', 'ride-456', 0, 0);
    expect(res.sent).toBe(false);
    expect(res.reason).toBe('no-api-key');
  });

  it('does not throw even with an invalid phone number', async () => {
    delete process.env.MSG91_API_KEY;
    const svc = new SmsService();
    // The service should never throw, even on weird input — failure to send
    // must not break the safety flow.
    await expect(
      svc.sendEmergencySms('not-a-phone', 'USER', 'ride-789', 0, 0),
    ).resolves.toBeDefined();
  });
});
