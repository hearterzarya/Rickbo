# Rickbo — रिक्शा, बस एक टैप

> **E-rickshaw booking app for Najibabad (Bijnor, UP).** Like Uber/Rapido,
> but **zero per-ride commission**, **fixed zone fares**, **Hindi-first UI**,
> voice-assisted for non-literate drivers, and a permanent safety record
> for every ride.

The full product spec lives in [`CLAUDE.md`](./CLAUDE.md) and the visual
design in [`DESIGN.md`](./DESIGN.md).

---

## ✨ What's working today

| Capability | Status |
|---|---|
| 🛺 **Reserve booking** (A–E zones, 1–4 pax) | ✅ end-to-end live |
| 👥 **Share matching** (2-min window + 3-button fallback) | ✅ end-to-end live |
| 📞 **Phone OTP** (Firebase phone auth) | ✅ |
| 🧪 **Dev Test OTP** (no Firebase needed) | ✅ |
| 🗺️ **OpenStreetMap** live tracking + pickup pin | ✅ |
| 📲 **FCM push** (ride offers to drivers) | ✅ |
| 🔌 **Socket.IO** real-time (ride:matched, location, status) | ✅ |
| 🔊 **Hindi voice** prompts (flutter_tts, offline) | ✅ |
| 🆘 **SOS** (3-sec hold, backend log + push + SMS hook) | ✅ |
| 🔗 **Public share-trip link** `/s/:token` (works in WhatsApp) | ✅ |
| ⭐ **Two-way ratings** + 🚩 complaints | ✅ |
| 💰 **Driver subscription** (extend endpoint, block if expired) | ✅ |
| 🌙 **Night surcharge** (+₹5, 21:00–06:00 IST) | ✅ |
| 📱 **Hindi voice prompts** for driver (सवारी है, पहुंच गए, सफ़र पूरा) | ✅ |
| 🎨 **Branding** (splash, icon, theme) | ✅ |
| 🌐 **Live backend** at `https://rickbo-production.up.railway.app` | ✅ |

---

## 🏗️ Repo layout

```
Rickbo/
├── backend/                      # NestJS + Prisma + PostgreSQL+PostGIS + Socket.IO
│   ├── src/modules/
│   │   ├── auth/                 # /auth/verify + dev /auth/test-otp/*
│   │   ├── users/                # POST /users, GET /users/me, PATCH /users/me
│   │   ├── drivers/              # CRUD, location, online toggle, subscription, nearest
│   │   ├── rides/                # create/accept/arrive/start/complete/cancel/share-action
│   │   ├── pricing/              # zone-based fare, IST night-surcharge
│   │   ├── matching/             # nearest-driver search, fallback
│   │   ├── realtime/             # Socket.IO gateway
│   │   └── safety/               # SOS, ratings, complaints
│   ├── prisma/schema.prisma      # full data model
│   ├── .env.example              # env template (no real secrets)
│   └── railway.toml              # Railway deploy config
├── packages/core/                # Flutter shared: models, API client, zones, fare table, theme, voice
│   ├── lib/
│   │   ├── zones.dart            # 5 Najibabad zones (A–E) with lat/lng/radius
│   │   ├── fares.dart            # RESERVE + SHARE tables from CLAUDE.md Section 3
│   │   ├── theme.dart            # Rickbo blue + Hindi font
│   │   ├── api/                  # Dio + Socket.IO client
│   │   ├── models/               # User, Driver, Ride, ActiveRide
│   │   └── widgets/              # HindiError, EmptyState, Voice, OfflineBanner
└── apps/
    ├── user_app/                 # Flutter — passenger app
    └── driver_app/               # Flutter — driver app (Hindi voice, big buttons)
└── admin_web/                    # Next.js 14 — operations + safety dashboard (web only)
    ├── app/
    │   ├── (app)/                # authed pages: dashboard, users, drivers, rides, sos, zones
    │   └── login/                # dev OTP login
    ├── components/ui/            # shadcn primitives
    └── lib/                      # api, auth (zustand), types, env, utils
```

---

## 🧰 Tech stack

**Backend** — NestJS (TypeScript) · Prisma · PostgreSQL 16 + PostGIS · Socket.IO · JWT auth · Firebase Admin (verify phone) · FCM (push) · Neon (hosted Postgres)

**Frontend** — Flutter 3.44 (Dart) · Riverpod 2.5 · go_router 13 · dio 5 · socket_io_client 2 · firebase_auth + firebase_messaging · flutter_map (OpenStreetMap) · geolocator · flutter_tts (Hindi voice, offline)

**Infra** — Railway (backend) · Neon (Postgres + PostGIS) · Firebase (auth + FCM) · OpenStreetMap (tiles) · Vercel (admin_web)

---

## 🖥️ Admin web (`admin_web/`)

A small Next.js 14 + shadcn/ui dashboard for ops and safety. **Not** the
driver or passenger app — for us (the team) only. Bilingual (Hindi +
English), dark theme, calls the same Railway backend the apps use.

| Page | What it shows |
|---|---|
| **Dashboard / डैशबोर्ड** | Live counts (users / drivers / rides / SOS) + 14-day ride sparkline |
| **Users / यात्री** | All registered users, search by phone/name, last seen |
| **Drivers / ड्राइवर** | All drivers, status, online toggle, subscription expiry, suspend/unsuspend |
| **Rides / सवारी** | All rides with status, fare, zone, driver, OTP — filter by status |
| **SOS / आपातकाल** | Active SOS events with map links, one-click **Mark Resolved** |
| **Zones / क्षेत्र** | The 5 fixed Najibabad zones (lat/lng/radius) + **Open in OSM** link |

### Login

Two dev paths (controlled by `NEXT_PUBLIC_ADMIN_DEV_LOGIN`):

1. **Dev login** (default in `.env.local`) — pick any role and a phone
   number, get a JWT instantly. For local development only.
2. **Real OTP** — uses the backend's `/auth/test-otp/start` and
   `/auth/test-otp/verify` (same path the Flutter apps use). The OTP
   shows in the response, paste it in.

### Run locally

```bash
cd admin_web
cp .env.example .env.local         # then edit
npm install
npm run dev                        # http://localhost:3000
```

The login screen takes:
- `NEXT_PUBLIC_API_URL` — the backend to talk to (e.g. `https://rickbo-production.up.railway.app`)
- `NEXT_PUBLIC_ADMIN_DEV_LOGIN` — `1` for dev-login, `0` for real OTP

### Build for production

```bash
npm run build
npm start
```

Deploy target: **Vercel** (one-click import, no env beyond the two
above). Build output: `.next/`.

---

## 🚀 Run locally

### 0. Prerequisites

| Tool | Version | Why |
|---|---|---|
| Node | 20+ | runs NestJS |
| Flutter | 3.44+ | builds the apps |
| Android Studio / SDK | API 33+ | runs the apps |
| PostgreSQL + PostGIS | 16 | local DB (or use Neon) |

### 1. Backend

```bash
cd backend
cp .env.example .env          # then edit values
npm install
npx prisma migrate dev        # creates tables on your local Postgres
npm run start:dev             # http://0.0.0.0:4000
```

You need a Postgres database with the **PostGIS** extension enabled. The
easiest path is a free [Neon](https://neon.tech) project — paste its
connection string into `DATABASE_URL`. To enable PostGIS on Neon, run
once via the Neon SQL console:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Required env vars (see `backend/.env.example`):

```
DATABASE_URL=postgresql://...neondb_owner.../neondb?sslmode=require
JWT_SECRET=<openssl rand -hex 32>
NODE_ENV=development
PORT=4000
# Optional — needed for prod FCM push:
FIREBASE_SERVICE_ACCOUNT_JSON=<one-line JSON>
SMS_API_KEY=<msg91 or fast2sms — only for SOS in prod>
R2_BUCKET=<cloudflare r2 bucket — optional, for photo evidence>
```

### 2. Flutter apps

```bash
# Shared package
cd packages/core
flutter pub get

# User app
cd ../../apps/user_app
flutter pub get
flutter run                    # emulator or device

# Driver app (second terminal)
cd ../driver_app
flutter pub get
flutter run
```

In each app, open **Dev Settings** (गियर icon on home) and set the API base URL:

| Where you run from    | API URL |
|-----------------------|---------|
| Android emulator      | `http://10.0.2.2:4000` |
| iOS simulator / web   | `http://127.0.0.1:4000` |
| Physical phone        | `http://<your-PC-LAN-IP>:4000` |
| ☁️ Live (Railway)      | `https://rickbo-production.up.railway.app` |

The Dev Settings URL is stored in `shared_preferences` and survives restarts.

### 3. Quick test login (no Firebase needed)

Each app's Dev Settings has a **Quick Test OTP** button. It hits the dev
endpoint on the backend (`POST /auth/test-otp/start`), which returns the
OTP in the response (so you can copy it). Then enter the OTP on the
login screen — the backend issues a JWT and you're in.

This works against **both** local dev and the live Railway backend.

---

## 🏗️ Deploy the backend to Railway

The Flutter apps run on user devices — no deploy needed. Only the NestJS
backend needs hosting.

### One-time setup

1. **Create a Neon project** at <https://neon.tech> (free tier, PostGIS
   support). Copy the connection string.
2. Enable PostGIS on Neon (run in Neon SQL console):
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```
3. **Create a Railway account** at <https://railway.app> (sign in with
   GitHub).

### Deploy

1. Railway dashboard → **New Project** → **Deploy from GitHub repo** →
   select `hearterzarya/Rickbo`.
2. Service settings:
   - **Root directory**: `backend`
   - **Builder**: Nixpacks (auto-detected)
3. **Variables** tab → add:

   | Name | Value |
   |---|---|
   | `DATABASE_URL` | the Neon connection string |
   | `JWT_SECRET` | `openssl rand -hex 32` |
   | `NODE_ENV` | `production` |
   | `ADMIN_KEY` | (optional) admin password |
   | `FIREBASE_SERVICE_ACCOUNT_JSON` | (optional) one-line JSON for prod FCM |

4. Click **Deploy**. First build: `npm ci` → `prisma generate` →
   `nest build` → `npm run start:prod`. ~2–3 minutes.

5. Copy the public URL (e.g. `rickbo-production.up.railway.app`).

6. **Smoke test**:
   ```bash
   curl https://rickbo-production.up.railway.app/pricing/zones | jq
   ```
   You should see 5 zones A–E.

7. **Open each Flutter app** → Dev Settings → set the API URL to the
   Railway URL. Done.

### Auto-deploy

Every push to `main` on GitHub triggers a fresh Railway build & deploy.

### Health check

Railway pings `GET /pricing/zones` every 30 s. That route is public, no
JWT, returns the 5 zones — perfect liveness probe.

---

## 💵 Pricing reference (5 zones × 5 zones)

**Reserve (पूरी रिक्शा, 1–4 pax, flat ₹):**

```
A: 20 25 25 30 35
B: 25 20 25 25 30
C: 25 25 20 25 25
D: 30 25 25 20 25
E: 35 30 25 25 20
```

**Share (साझा सवारी, per-head ₹):**

```
A: 10 10 10 10 15
B: 10 10 10 10 12
C: 10 10 10 10 10
D: 10 10 10 10 10
E: 15 12 10 10 10
```

**Rules**
- Same-zone: Reserve ₹20, Share ₹10.
- Night surcharge (21:00–06:00 **IST**): +₹5 to every fare.
- Reserve = 1–4 pax, same flat fare. >4 passengers → blocked ("दूसरी रिक्शा बुक करें").
- Point outside any zone radius → nearest zone center.

Fare code lives in two places (kept in sync):
- `packages/core/lib/fares.dart` — Flutter (for client preview)
- `backend/src/modules/pricing/pricing.service.ts` — authoritative (server-enforced)

---

## 🧪 Test the live backend (curl one-liners)

```bash
# Public health
curl https://rickbo-production.up.railway.app/pricing/zones

# Fare preview
curl "https://rickbo-production.up.railway.app/pricing/fare?from=A&to=E&mode=reserve"
# → {"from":"A","to":"E","mode":"reserve","fare":35,"night":false}

# Start a test OTP (no Firebase needed)
curl -X POST https://rickbo-production.up.railway.app/auth/test-otp/start \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919876500101","role":"user"}'
# → {"ok":true,"devOtp":"123456"}

# Verify (returns JWT)
curl -X POST https://rickbo-production.up.railway.app/auth/test-otp/verify \
  -H "Content-Type: application/json" \
  -d '{"phone":"+919876500101","otp":"123456","role":"user"}'
```

---

## 📱 Building production APKs

```bash
# User app
cd apps/user_app
flutter build apk --release          # → build/app/outputs/flutter-apk/app-release.apk
# or
flutter build appbundle --release    # → build/app/outputs/bundle/release/app.aab (for Play Store)

# Driver app
cd ../driver_app
flutter build apk --release          # same
```

For a Play Store release you'll need a real signing key. The debug key
auto-generated by Android Studio works for sideloading.

**Default Firebase config** — the apps expect `google-services.json` /
`GoogleService-Info.plist` in `apps/<app>/`. For dev/testing, the
**Quick Test OTP** flow works without Firebase.

---

## 🛠️ Troubleshooting

| Symptom | Fix |
|---|---|
| `dio: connection refused` on emulator | Set API URL to `http://10.0.2.2:4000` (not `localhost`) |
| `SocketException: Failed host lookup` | No internet, or wrong host |
| `prisma generate` fails on first build | The Railway build runs `prisma generate` automatically |
| `PostGIS not found` error | Run `CREATE EXTENSION postgis;` in your Neon SQL console |
| `401 Unauthorized` on every API call | JWT expired or not attached. Check Dio interceptor in `packages/core/lib/api/api_client.dart` |
| Flutter app shows `CORS error` | Only the browser version needs CORS — the backend already allows `*` |
| Hindi TTS speaks nothing | Make sure the Android device has Google TTS engine + Hindi language pack installed |
| `flutter_tts` build fails | Make sure `flutter pub get` was run in `packages/core/` first (it's a workspace dep) |

---

## 🗺️ Live deployment (no setup needed)

The backend is already deployed and reachable at:

```
https://rickbo-production.up.railway.app
```

Free public endpoints (no JWT):
- `GET  /pricing/zones` — list of 5 zones
- `GET  /pricing/fare?from=A&to=C&mode=reserve` — fixed fare
- `GET  /s/:token` — public "सफ़र शेयर करें" page

Full API requires a JWT (Firebase verify or dev Test OTP).

Database: Neon PostgreSQL (PostGIS) — provisioned via Neon free tier.

---

## 📜 License

MIT (placeholder — change before public launch).

---

## 🙏 Credits

- OpenStreetMap contributors for map tiles
- Google Noto Sans Devanagari for Hindi text rendering
- Every Najibabad e-rickshaw driver who'll use this
