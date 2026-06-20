# Rickbo — Master Build Spec (CLAUDE.md)

> Naya project, sab kuch zero se. Frontend = **Flutter**, Backend = **NestJS** (dono naye).
> Is file ko project root mein `CLAUDE.md` rakho. Claude Code har baar isay padhega.
> Phase prompts (Section 8) ek-ek karke do — sab ek saath mat do.

---

## 1. PROJECT OVERVIEW

**Naam:** Rickbo — *रिक्शा, बस एक टैप*
**Kya hai:** E-rickshaw booking app for a small Indian town (Najibabad, Bijnor, UP). Like 
Uber/Rapido but town-level, zero-commission, Hindi-first, for non-technical drivers and 
passengers. The local rickshaws are open-canopy 3-wheeler "मिनी मेट्रो" type e-rickshaws.

**Core principles (kabhi mat todna):**
- **Zero per-ride commission.** Driver pays a monthly subscription; full fare = cash to driver.
- **Fixed zone-based pricing.** NO surge, NO bidding. Fares come from a fixed table.
- **Hindi-first, voice-assisted UI.** A non-literate driver must use it. Big buttons, icons, 
  Hindi voice prompts, NO typing for drivers.
- **Safety is the moat.** Every ride trackable, an SOS path, a permanent record.
- **Cheap to run.** Free-tier services only (OpenStreetMap, FCM, Firebase Auth).

**Two ride modes:**
- **Reserve (पूरी रिक्शा):** whole rickshaw, 1–4 passengers, flat fare. Build FIRST.
- **Share (साझा सवारी):** per-head cheaper, others may join, 2-minute match window. Later.

---

## 2. TECH STACK (all new)

### Frontend — Flutter
| Concern | Choice |
|---|---|
| Framework | Flutter (latest stable) + Dart |
| State | Riverpod |
| Navigation | go_router |
| HTTP | dio (interceptors: base URL + auth token) |
| Realtime | socket_io_client |
| Auth/OTP | firebase_auth (phone) |
| Push | firebase_messaging (FCM) |
| Local storage | shared_preferences (token, profile, dev API URL) |
| Maps | flutter_map (OpenStreetMap tiles) — NOT Google Maps |
| Location | geolocator + permission_handler |
| Voice (driver) | audioplayers + pre-bundled Hindi MP3s |
| Fonts | google_fonts (Hind / Noto Sans Devanagari) |

### Backend — NestJS
| Concern | Choice |
|---|---|
| Framework | NestJS (TypeScript) |
| ORM/DB | Prisma + PostgreSQL + PostGIS |
| Realtime | Socket.IO gateway |
| Auth | Firebase Admin (verify phone token) + JWT |
| Push | Firebase Admin (FCM send) |
| SMS (SOS) | MSG91 / Fast2SMS |
| Storage | Cloudflare R2 (photos, evidence) |
| Hosting | Railway or a small AWS instance |

### Project structure
```
rickbo/
├── backend/                 # NestJS
│   ├── src/modules/{auth,users,drivers,rides,matching,pricing,safety,realtime}/
│   └── prisma/schema.prisma
├── packages/core/           # Flutter shared: models, api client, zones, fare table, theme
└── apps/
    ├── user_app/            # Flutter
    └── driver_app/          # Flutter
```
(Admin/control room can be added later as a small Next.js app; not required for MVP launch.)

---

## 3. ZONES & PRICING (hard data — use exactly)

```dart
// packages/core/lib/zones.dart
const zones = [
  {'id':'A','name':'स्टेशन / बस अड्डा','lat':29.6039,'lng':78.3365,'radius':500},
  {'id':'B','name':'स्टेशन रोड / अस्पताल','lat':29.6089,'lng':78.3363,'radius':450},
  {'id':'C','name':'पुराना बाज़ार / तहसील','lat':29.6125,'lng':78.3406,'radius':450},
  {'id':'D','name':'नई तहसील / कोर्ट','lat':29.6081,'lng':78.3472,'radius':450},
  {'id':'E','name':'कोटद्वार रोड / सेंट मेरी','lat':29.6105,'lng':78.3522,'radius':500},
];
```

**SHARE fare (per passenger), ₹** — rows = from, cols = to (A,B,C,D,E):
```
A: 10 10 10 10 15
B: 10 10 10 10 12
C: 10 10 10 10 10
D: 10 10 10 10 10
E: 15 12 10 10 10
```
**RESERVE fare (whole rickshaw, 1–4 pax, flat), ₹:**
```
A: 20 25 25 30 35
B: 25 20 25 25 30
C: 25 25 20 25 25
D: 30 25 25 20 25
E: 35 30 25 25 20
```
Rules: same-zone Share ₹10 / Reserve ₹20. Night (21:00–06:00): +₹5 on every fare. Reserve 
1–4 pax = same fare; >4 blocked (suggest 2nd rickshaw). Point outside any zone radius → 
nearest zone center.

```dart
int getFare(String from, String to, String mode, bool isNight) {
  final base = mode == 'reserve' ? reserveTable[from]![to]! : shareTable[from]![to]!;
  return base + (isNight ? 5 : 0);
}
```

---

## 4. DATA MODEL (Prisma)

- **User**: id, phone (unique), name, photoUrl, fcmToken, trustScore (default 0), createdAt.
- **Driver**: id, phone, name, photoUrl, rickshawNumber, aadhaarVerified, policeVerified, 
  status (PENDING/ACTIVE/SUSPENDED/BANNED), isOnline, location (PostGIS geography point), 
  fcmToken, subscriptionValidUntil, ratingAvg, createdAt.
- **Ride**: id, userId, driverId, mode (RESERVE/SHARE), fromZone, toZone, pickup/drop 
  lat-lng, fare, passengerCount, status (REQUESTED/MATCHED/ARRIVED/ONGOING/COMPLETED/
  CANCELLED), otp (4-digit), gpsPath (jsonb), requestedAt, startedAt, completedAt.
- **SosEvent**: id, rideId, raisedBy (USER/DRIVER), lat, lng, createdAt, resolved, notes.
- **Rating**: id, rideId, by, stars, comment.
- **Complaint**: id, rideId, against, reason, severity, status.

Use PostGIS geography(Point) for driver location + pickup so nearest-driver works via 
ST_DWithin / ST_Distance.

---

## 5. BACKEND API (build these)

- `POST /auth/verify` — verify Firebase phone token, return app JWT.
- `POST /users` , `GET /users/me` — user profile.
- `POST /drivers` , `GET /drivers/me` — driver profile.
- `POST /drivers/me/location` — driver sends GPS (REQUIRED before going online).
- `POST /drivers/me/online` , `POST /drivers/me/offline` — toggle.
- `POST /rides` — create ride (mode, fromZone, toZone, pax) → matching starts.
- `POST /rides/:id/accept` (driver), `/arrive`, `/start` (OTP verify), `/complete`, `/cancel`.
- `POST /sos` — emergency: log + realtime alert + SMS.
- `POST /ratings` , `POST /complaints`.
- Socket.IO: driver receives ride offers; user receives driver location + status; control 
  events. Auth the socket with the JWT.

Matching (simple MVP): on ride create → resolve pickup zone → find nearest online+ACTIVE 
drivers (PostGIS) → offer one-by-one, 20s each → first accept locks the ride.

---

## 6. KEY FLOWS

### Reserve booking (Phase 2 — first)
1. User home → big "🛺 रिक्शा बुलाओ".
2. Pickup from GPS → nearest zone. Destination chosen from a LIST of zones (not a map).
3. Show fixed Reserve fare "₹25 — पक्का किराया" → "बुक करें".
4. Backend offers nearest drivers one-by-one (20s each).
5. Driver: loud FCM + in-app alert + Hindi voice "सवारी है — स्टेशन — ₹25" → हाँ/ना.
6. Accept → OTP made; driver card (photo/name/number/phone) to user; live track + 
   "सफ़र शेयर करें" link.
7. Reach → user tells OTP → driver enters → ongoing → drop → "सफ़र पूरा" → cash → rate.

### Driver go-online (location first!)
On "ऑनलाइन": request location permission → get GPS → `POST /drivers/me/location` → then 
online. While online, send location every ~10–15s. Hindi errors for permission denied / 
GPS off. Never block UI on failure.

### SOS (Phase 3)
Big red SOS button always visible during a ride → `POST /sos` (ride_id + live lat/lng) → 
backend alerts + SMS. Never show raw API/HTML in dialogs — only clean Hindi messages.

### Share (Phase 4)
2-min dynamic window, seat-fill on a rickshaw already heading the same way, detour limit, 
3-button fallback (अकेले ₹25 discount / 1 min aur / cancel).

---

## 7. DEV SETTINGS (must have)
A screen to set API base URL at runtime, stored in shared_preferences. Hints shown:
- Android emulator: `http://10.0.2.2:4000`
- iOS sim / web: `http://127.0.0.1:4000`
- Physical phone: `http://<PC-LAN-IP>:4000` (e.g. http://192.168.1.12:4000)
This is essential because a physical phone can't reach localhost.

---

## 8. BUILD ORDER — give ONE phase at a time. After each: stop, tell me what to test, wait.

### ▶ PHASE 0 — Scaffold (backend + flutter)
```
Read CLAUDE.md and DESIGN.md fully. Create:
- backend/ NestJS app with Prisma + PostgreSQL + PostGIS; generate the full schema from 
  Section 4; add .env.example; modules folders from Section 2; app listens on 0.0.0.0:4000 
  with CORS enabled.
- Flutter workspace: packages/core (models, dio api client with base-URL+token interceptors, 
  zones.dart + fare tables from Section 3, theme from DESIGN.md), apps/user_app, 
  apps/driver_app with Riverpod + go_router + firebase + socket_io_client + flutter_map + 
  geolocator. Add the Dev Settings screen (Section 7).
No features yet. Give me setup + run steps for both backend and apps.
```

### ▶ PHASE 1 — Auth + profiles + pricing
```
Read CLAUDE.md. Backend: POST /auth/verify (firebase token → JWT), POST/GET users + drivers, 
pricing module from Section 3 (unit-tested), zone resolution, driver location + online 
toggle + nearest-driver query. Flutter: firebase phone auth, first-time registration screen 
(name; rickshaw number for driver), store JWT+profile, attach token to dio. Verify booking/
online calls send the token.
```

### ▶ PHASE 2 — Reserve flow + realtime (thin slice)
```
Read CLAUDE.md Section 6. Build end-to-end Reserve booking for zones A/B/C: backend ride 
create + matching + Socket.IO + FCM offer + OTP + complete. Flutter user screens (home, 
zone-list destination, fare confirm, searching, driver card, live track, rating) and driver 
screens (online toggle that sends location FIRST, incoming offer हाँ/ना + Hindi voice, 
navigate arrow, OTP entry, complete). Match DESIGN.md exactly.
```

### ▶ PHASE 3 — Safety
```
Read CLAUDE.md Section 6. SOS button both apps → POST /sos; "सफ़र शेयर करें" live link; 
two-way ratings + complaints; auto-flag repeat offenders. All errors as clean Hindi dialogs, 
never raw API/HTML.
```

### ▶ PHASE 4 — Share + zones D/E + subscription
```
Read CLAUDE.md Section 6 Share. Implement Share matching (dynamic window, seat-fill, detour 
limit, 3-button fallback), add zones D/E, driver subscription tracking (block if expired).
```

### ▶ PHASE 5 — Polish & build
```
Read CLAUDE.md + DESIGN.md. Error/empty/offline states, Hindi voice prompts on all driver 
events, app icon + splash (Rickbo logo), flutter build apk config, seed/test login, README 
with full run + deploy steps (backend on Railway/AWS, Firebase, R2).
```

---

## 9. GUARDRAILS
- Everything new — no legacy code. Frontend Flutter, backend NestJS.
- Maps = OpenStreetMap (flutter_map), never Google Maps paid APIs.
- Fares ONLY from Section 3 tables. No surge, no bidding.
- Hindi-first, big buttons, voice for driver, no driver typing.
- Dev Settings must change API base URL at runtime (physical phone needs PC LAN IP).
- Build phase-by-phase; don't jump ahead. Ask before any paid service or schema change 
  beyond Section 4, or any deviation from these specs.
- Keep code typed, modular, with simple English comments.
```
