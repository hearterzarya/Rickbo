#!/usr/bin/env node
// E2E matching test against a given base URL (default Railway).
// Usage: node scripts/test_matching_railway.js [baseUrl]

const io = require('socket.io-client');
const http = require(process.env.USE_HTTPS === '0' ? 'http' : 'https');

const BASE = process.argv[2] || 'https://rickbo-production.up.railway.app';

function postJson(path, body, token) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const url = new URL(BASE + path);
    const opts = {
      method: 'POST',
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
      },
    };
    const req = http.request(opts, (res) => {
      let chunks = '';
      res.on('data', (c) => (chunks += c));
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(chunks) }); }
        catch { resolve({ status: res.statusCode, body: chunks }); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

(async () => {
  console.log(`=== Phase 2 matching test on ${BASE} ===`);

  // 1. Reset all online drivers first via admin
  const adminLogin = await postJson('/auth/test-otp', { phone: '+919999000111', role: 'admin' });
  if (adminLogin.status !== 201) { console.error('admin login failed', adminLogin); process.exit(1); }
  const resetRes = await postJson('/admin/dev/reset-online-drivers', {}, adminLogin.body.token);
  console.log('reset online drivers:', resetRes);

  // 2. Driver login + go online
  const dr = await postJson('/auth/test-otp', { phone: '+919876500001', role: 'driver' });
  if (dr.status !== 201) { console.error('driver login failed', dr); process.exit(1); }
  const driverToken = dr.body.token;
  const driverId = dr.body.profile.id;
  console.log('driver login OK', driverId);
  await postJson('/drivers/me/location', { lat: 29.6040, lng: 78.3366 }, driverToken);
  await postJson('/drivers/me/online', {}, driverToken);
  console.log('driver online at zone A');

  // 3. Driver socket connect
  const sock = io(BASE, { transports: ['websocket'], auth: { token: driverToken }, reconnection: false });
  const driverEvents = [];
  sock.onAny((evt, data) => driverEvents.push({ evt, data }));
  await new Promise((r) => sock.on('connect', r));
  console.log('[driver] socket connected');

  // 4. User login + create ride
  const ur = await postJson('/auth/test-otp', { phone: '+919876500002', role: 'user' });
  const userToken = ur.body.token;
  const usock = io(BASE, { transports: ['websocket'], auth: { token: userToken }, reconnection: false });
  const userEvents = [];
  usock.onAny((evt, data) => userEvents.push({ evt, data }));
  await new Promise((r) => usock.on('connect', r));
  console.log('[user] socket connected');

  const rideRes = await postJson('/rides', {
    mode: 'RESERVE',
    fromZone: 'A',
    toZone: 'B',
    pickupLat: 29.6039,
    pickupLng: 78.3365,
    passengerCount: 1,
  }, userToken);
  if (rideRes.status !== 201) { console.error('ride failed', rideRes); process.exit(1); }
  const rideId = rideRes.body.id;
  console.log('ride created', rideId);

  // 5. Wait for offer (max 90s — offers 1 driver/20s)
  const start = Date.now();
  let offerEvts = [];
  while (Date.now() - start < 90_000) {
    offerEvts = driverEvents.filter((e) => e.evt === 'ride:offer' && e.data?.rideId === rideId);
    if (offerEvts.length > 0) break;
    await new Promise((r) => setTimeout(r, 1000));
  }
  console.log(`[driver] got ${offerEvts.length} ride:offer events for our ride in ${Math.round((Date.now() - start) / 1000)}s`);
  if (!offerEvts.length) {
    console.error('NO OFFER RECEIVED — all driver events:', driverEvents.map(e => e.evt));
    process.exit(1);
  }

  // 6. Accept
  const acceptRes = await postJson(`/rides/${rideId}/accept`, {}, driverToken);
  console.log('accept:', acceptRes.status, acceptRes.body?.status);

  // 7. Wait for user match event
  await new Promise((r) => setTimeout(r, 2000));
  const matchedEvts = userEvents.filter((e) => e.evt === 'ride:matched');
  console.log(`[user] got ${matchedEvts.length} ride:matched events`);
  if (!matchedEvts.length) {
    console.error('NO MATCH RECEIVED — all user events:', userEvents.map(e => e.evt));
    process.exit(1);
  }
  console.log('[user] match data:', JSON.stringify(matchedEvts[0].data, null, 2));
  console.log('=== END-TO-END OK ===');
  process.exit(0);
})();
