#!/usr/bin/env node
// Phase 2 end-to-end matching smoke test:
//  1. loginTestOtp(driver) + goOnline + simulate location
//  2. open socket as driver
//  3. loginTestOtp(user) + create ride RESERVE A->B
//  4. driver socket should receive 'ride:offer'
//  5. driver emits 'ride:accept' via REST
//  6. user socket should receive 'ride:matched'

const io = require('socket.io-client');
const http = require('http');

const BASE = process.env.BASE || 'http://localhost:4000';

function postJson(path, body, token) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const url = new URL(BASE + path);
    const opts = {
      method: 'POST',
      hostname: url.hostname,
      port: url.port,
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
  console.log('=== Phase 2 matching smoke test ===');

  // 1. driver login + online
  const driverPhone = '+919876500001';
  const dr = await postJson('/auth/test-otp', { phone: driverPhone, role: 'driver' });
  if (dr.status !== 201) { console.error('driver login failed', dr); process.exit(1); }
  const driverToken = dr.body.token;
  const driverId = dr.body.profile.id;
  console.log('driver login OK', driverId);

  // Set driver location right at the pickup point (zone A center) so it ranks first.
  // We use a fresh unique location to make it the *nearest* driver.
  await postJson('/drivers/me/location', { lat: 29.6040, lng: 78.3366 }, driverToken);
  await postJson('/drivers/me/online', {}, driverToken);
  console.log('driver online at (29.6040, 78.3366)');

  // Wait for any leftover ride offer matching loops to drain.
  // (Phase 2 matching offers a ride to one driver for 20s, so a stuck test run
  // from a previous attempt can keep us blocked for a while. 25s is safe.)
  await new Promise((r) => setTimeout(r, 25_000));
  console.log('Waited 25s for any pending offers to time out');

  // 2. open driver socket
  const sock = io(BASE, {
    transports: ['websocket'],
    auth: { token: driverToken },
    reconnection: false,
  });
  const driverEvents = [];
  sock.on('connect', () => console.log('[driver] socket connected'));
  sock.on('auth:ok', (d) => console.log('[driver] auth:ok', d));
  sock.on('auth:error', (d) => { console.error('[driver] auth:error', d); process.exit(1); });
  sock.onAny((evt, data) => driverEvents.push({ evt, data }));

  await new Promise((r) => sock.on('connect', r));

  // 3. user login + create ride A->B
  const userPhone = '+919876500002';
  const ur = await postJson('/auth/test-otp', { phone: userPhone, role: 'user' });
  if (ur.status !== 201) { console.error('user login failed', ur); process.exit(1); }
  const userToken = ur.body.token;
  console.log('user login OK');

  const usock = io(BASE, {
    transports: ['websocket'],
    auth: { token: userToken },
    reconnection: false,
  });
  const userEvents = [];
  usock.onAny((evt, data) => userEvents.push({ evt, data }));
  await new Promise((r) => usock.on('connect', r));
  console.log('[user] socket connected');

  // Create ride A -> B, pickup at zone A center
  const rideRes = await postJson('/rides', {
    mode: 'RESERVE',
    fromZone: 'A',
    toZone: 'B',
    pickupLat: 29.6039,
    pickupLng: 78.3365,
    passengerCount: 1,
  }, userToken);
  console.log('ride create:', rideRes.status, rideRes.body?.id || rideRes.body);
  if (rideRes.status !== 201) { console.error('ride failed', rideRes); process.exit(1); }
  const rideId = rideRes.body.id;

  // 4. wait up to 90s for ride:offer on driver (matching offers drivers one-by-one, 20s each).
  // We only consider the offer for *our* new ride, not any leftover offers from
  // previous test runs.
  const start = Date.now();
  let offerEvts = [];
  while (Date.now() - start < 90_000) {
    offerEvts = driverEvents.filter((e) => e.evt === 'ride:offer' && e.data?.rideId === rideId);
    if (offerEvts.length > 0) break;
    await new Promise((r) => setTimeout(r, 1000));
  }
  console.log(`[driver] received ${offerEvts.length} ride:offer events for our ride after ${Math.round((Date.now() - start) / 1000)}s`);
  if (offerEvts.length === 0) {
    console.error('NO OFFER RECEIVED BY DRIVER — flow is broken');
    console.error('all driver events:', driverEvents);
    process.exit(1);
  }
  console.log('[driver] offer data:', offerEvts[0].data);

  // 5. driver accepts via REST
  const acceptRes = await postJson(`/rides/${rideId}/accept`, {}, driverToken);
  console.log('accept:', acceptRes.status, acceptRes.body?.status || acceptRes.body);
  if (acceptRes.status !== 201) {
    console.error('accept failed', acceptRes);
    process.exit(1);
  }

  // 6. wait for user ride:matched
  await new Promise((r) => setTimeout(r, 2000));
  const matchedEvts = userEvents.filter((e) => e.evt === 'ride:matched');
  console.log(`[user] received ${matchedEvts.length} ride:matched events`);
  if (matchedEvts.length === 0) {
    console.error('NO ride:matched RECEIVED BY USER');
    console.error('all user events:', userEvents);
    process.exit(1);
  }
  console.log('[user] match data:', matchedEvts[0].data);

  console.log('=== END-TO-END OK ===');
  sock.close();
  usock.close();
  process.exit(0);
})();
