# Deploying admin_web to Vercel

> One-time, ~5 minutes. The dashboard route is the simplest path — no CLI install.

## 1. Sign in
Go to https://vercel.com/signup and sign in with **the GitHub account that owns this repo** (hearterzarya).

## 2. Import the project
- Click **Add New → Project**
- Pick `hearterzarya/Rickbo` from the list
- **Root Directory** → click "Edit" → set it to `admin_web`
  (Vercel will only see admin_web/, not the Flutter apps — that keeps build size sane)
- Framework preset: **Next.js** (auto-detected)
- Build command: `next build` (default)
- Output directory: `.next` (default)
- Install command: `npm install` (default)

## 3. Environment variables
On the same screen, expand **Environment Variables** and add:

| Name | Value | Scope |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | `https://rickbo-production.up.railway.app` | Production + Preview |
| `NEXT_PUBLIC_ADMIN_DEV_LOGIN` | `1` | Production (for now — flips off once real OTP is wired) |

The defaults already match what's in `.env.example`, so you can also copy from there.

## 4. Deploy
- Click **Deploy**
- First build takes ~1–2 minutes (Next 14, ~12 static pages)
- When green, you'll get a URL like `rickbo-admin.vercel.app`

## 5. Smoke test (5 mins)
Open the URL. Verify:

1. `/` redirects to `/login` ✓
2. Login screen shows "रिक्बो Admin" with Hindi font ✓
3. Pick any phone number (e.g. 9000000000), enter any 6-digit OTP — you get in (dev login) ✓
4. Dashboard loads with real numbers: 44 users, 31 drivers, 6 open SOS, 5 ongoing rides ✓
5. Click around: Drivers, Rides, SOS, Zones — all load ✓
6. Open SOS, click the lat/lng — should jump to Najibabad on OpenStreetMap ✓

If numbers are 0/0/0/0 → backend isn't reachable → check the Railway env var is right.

## 6. Custom domain (optional)
In Vercel → Project → Settings → Domains, add `admin.rickbo.app` (or whatever you own).
Add the CNAME record to your DNS. Vercel auto-issues a TLS cert.

## Updating later
Just `git push origin main`. Vercel watches the repo and re-deploys `admin_web/` on every commit automatically. No manual step.

## Why a custom dashboard and not the Flutter admin_app?
- 12 pages, 87 kB shared JS — opens in any browser, on any phone, no APK install
- shadcn/ui is dark-theme by default → easy on ops eyes during late shifts
- SWR polling at 5s/10s/15s → live numbers without a websocket setup
- Hosted on Vercel (free tier is fine for ops traffic) — no Railway egress cost
- Operates on the same `/admin/*` endpoints Flutter app was using, so no backend change

## Why Mumbai (`bom1`) region?
- Lowest latency to Railway's nearest region
- Vercel's `bom1` is their Mumbai edge — closer to Najibabad than `iad1` or `fra1`
