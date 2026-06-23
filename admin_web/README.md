# admin_web — Rickbo operations dashboard

A small Next.js 14 dashboard for ops + safety. Web only (Vercel). Calls
the same NestJS backend the Flutter apps use.

## Pages

| Path | What |
|---|---|
| `/login` | Dev login (any phone) or real OTP (via backend) |
| `/dashboard` | Counts + 14-day ride sparkline |
| `/users` | All users, search by phone/name |
| `/drivers` | All drivers, online toggle, suspend |
| `/rides` | All rides, filter by status |
| `/sos` | Active SOS, mark resolved |
| `/zones` | 5 hard-coded Najibabad zones + OSM link |

## Run

```bash
cp .env.example .env.local
npm install
npm run dev          # http://localhost:3000
```

Build:

```bash
npm run build
npm start
```

## Env

```
NEXT_PUBLIC_API_URL=https://rickbo-production.up.railway.app
NEXT_PUBLIC_ADMIN_DEV_LOGIN=1
```

- `NEXT_PUBLIC_API_URL` — backend to talk to
- `NEXT_PUBLIC_ADMIN_DEV_LOGIN=1` — bypass OTP for local dev
  (set to `0` to use real OTP, OTP comes back in the dev-OTP response)

## Stack

Next.js 14 (App Router) · TypeScript · Tailwind · shadcn/ui · zustand
(token) · swr (data) · lucide-react (icons) · recharts (sparkline).

## Folder layout

```
admin_web/
├── app/
│   ├── (app)/            # authed layout + all ops pages
│   └── login/            # dev / real OTP
├── components/ui/        # shadcn primitives
├── lib/
│   ├── api.ts            # fetch wrapper (auth header, base URL)
│   ├── auth.ts           # zustand store (token, profile)
│   ├── env.ts            # reads NEXT_PUBLIC_* with safe defaults
│   └── types.ts          # User / Driver / Ride / SosEvent / Zone
└── .env.example
```

## Notes

- Auth: JWT from `/auth/test-otp/verify` stored in zustand + mirrored to
  `localStorage` (so a refresh keeps you in). API client attaches
  `Authorization: Bearer …` to every call.
- Zones are hard-coded on the server; this page is **read-only** by
  design (changing a zone would need a backend deploy + Flutter rebuild
  since `packages/core/lib/zones.dart` mirrors the same data).

## Screenshots

[`docs/screenshots/`](docs/screenshots/) — login, dashboard, drivers,
sos, zones.