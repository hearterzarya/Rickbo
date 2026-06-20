# Rickbo — रिक्शा, बस एक टैप

> Town-level e-rickshaw booking app for Najibabad (Bijnor, UP).
> Like Uber / Rapido — but **zero per-ride commission**, **fixed zone fares**,
> **Hindi-first UI**, voice-assisted for non-literate drivers, and a permanent
> safety record for every ride.

---

## What it does

- **Passengers** tap a big 🛺 button, pick a destination zone (no typing), see a
  **fixed fare** (no surge, no bidding), and watch their driver arrive on a live
  map.
- **Drivers** flip one switch to go online (the app sends GPS *first*), and get
  a loud Hindi voice prompt "सवारी है — स्टेशन — ₹25" with one-tap हाँ/ना.
- **Pricing** is a 5×5 table of zones in Najibabad — A through E — with
  flat rates per pair (₹20–35 for the whole rickshaw, ₹10–15 per head for
  share).
- **Safety** is the moat: every ride tracked, SOS button during the ride,
  share-your-trip link, two-way ratings, complaint system.
- **Cost of running the backend**: free tier only (Neon Postgres, Railway
  hosting, Firebase Auth, FCM, OpenStreetMap, Cloudflare R2).

---

## Repo layout

```
Rickbo/
├── backend/                 # NestJS + Prisma + PostgreSQL+PostGIS + Socket.IO
│   ├── src/modules/         # auth, users, drivers, rides, matching, pricing, safety, realtime
│   ├── prisma/schema.prisma # full data model (User, Driver, Ride, SosEvent, ...)
│   ├── railway.toml         # Railway deploy config
│   ├── nixpacks.toml        # apt packages for build
│   └── .env.example         # env template (no real secrets)
├── packages/core/           # Flutter shared: models, API client, zones, fare table, theme
└── apps/
    ├── user_app/            # Flutter app for passengers
    └── driver_app/          # Flutter app for drivers (Hindi voice, big buttons)
```

The full design lives in [`CLAUDE.md`](./CLAUDE.md) and [`DESIGN.md`](./DESIGN.md).

---

## Tech stack

**Backend** — NestJS (TypeScript) · Prisma · PostgreSQL + PostGIS · Socket.IO · JWT auth · Firebase Admin (verify phone token) · FCM (push) · Neon (hosted Postgres)

**Frontend** — Flutter (Dart) · Riverpod · go_router · dio (HTTP) · socket_io_client · firebase_auth + firebase_messaging · flutter_map (OpenStreetMap) · geolocator · audioplayers (Hindi voice prompts)

---

## Run locally

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
connection string into `DATABASE_URL`.

### 2. Flutter apps

```bash
# Shared package — models, API client, zone list, fare tables
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

In each app, open **Dev Settings** (गियर icon) and set the API base URL:

| Where you run from    | API URL                          |
|-----------------------|----------------------------------|
| Android emulator      | `http://10.0.2.2:4000`           |
| iOS simulator / web   | `http://127.0.0.1:4000`          |
| Physical phone        | `http://<your-PC-LAN-IP>:4000`   |

The Dev Settings screen stores the URL in `shared_preferences` so it
survives restarts.

---

## Deploy to Railway (backend only)

The Flutter apps run on user devices and don't need deployment. The **only
piece to deploy** is the NestJS backend.

### One-time setup

1. **Create a Neon project** at <https://neon.tech> (free tier, has PostGIS
   support). Copy the connection string — looks like
   `postgresql://neondb_owner:xxx@ep-xxx-pooler.c-4.us-east-1.aws.neon.tech/neondb?sslmode=require`.

2. **Push the code** to GitHub (this repo, public).

3. **Create a Railway account** at <https://railway.app> (sign in with
   GitHub).

### Deploy

1. Railway dashboard → **New Project** → **Deploy from GitHub repo** →
   select `hearterzarya/Rickbo`.

2. In the service settings:
   - **Root directory**: `backend`
   - **Builder**: Nixpacks (auto-detected)

3. **Variables** tab → add:

   | Name           | Value                                        |
   |----------------|----------------------------------------------|
   | `DATABASE_URL` | the Neon connection string from step 1      |
   | `JWT_SECRET`   | a random 64-char string (e.g. `openssl rand -hex 32`) |
   | `ADMIN_KEY`    | a password for the admin endpoints (e.g. `rickbo-admin`) |
   | `NODE_ENV`     | `production`                                 |

4. Click **Deploy**. First build does `npm ci` → `prisma generate` →
   `nest build` → `npm run start:prod`. ~2 minutes.

5. Once green, copy the public URL Railway generates
   (e.g. `rickbo-backend-production.up.railway.app`).

6. **Smoke test**:
   ```bash
   curl https://rickbo-backend-production.up.railway.app/pricing/zones | jq
   ```
   You should see the 5 zones (A–E) listed.

7. **Wire Flutter apps to the live URL**:
   - In each app open Dev Settings.
   - Set the API base URL to `https://rickbo-backend-production.up.railway.app`.

### Health check

Railway will ping `GET /pricing/zones` every 30 s to confirm the service
is alive. That route is public and returns the 5 Najibabad zones — perfect
for a no-auth liveness probe.

### Auto-deploy

Railway auto-redeploys on every push to `main` on GitHub. To deploy a
change:

```bash
git push origin main
```

---

## Pricing reference (5 zones × 5 zones)

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

Night (21:00–06:00) adds ₹5 to every fare. Same-zone: Reserve ₹20, Share ₹10.

See [`packages/core/lib/zones.dart`](./packages/core/lib/zones.dart) and
[`backend/src/modules/pricing/pricing.service.ts`](./backend/src/modules/pricing/pricing.service.ts).

---

## Build order

This project was built phase by phase — see [`CLAUDE.md`](./CLAUDE.md) Section 8.

- ✅ Phase 0 — scaffold (backend + flutter + dev settings)
- ✅ Phase 1 — auth + profiles + pricing
- ✅ Phase 2 — Reserve flow end-to-end (zones A–E)
- ✅ Phase 3 — safety (SOS, share-trip, ratings, complaints)
- ⏳ Phase 4 — Share matching + subscription (next)
- ⏳ Phase 5 — polish, build APKs, deploy

---

## License

MIT (placeholder — change before public launch).
