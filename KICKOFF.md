# Rickbo (New Flutter Project) — Claude Code Kickoff

Saari files (CLAUDE.md, DESIGN.md, zones-pricing.md, logo) ek naye khali project folder mein 
rakho. Claude Code khol. Phir yeh prompt paste karo:

---

```
You are building "Rickbo" from scratch — a new project. Frontend = FLUTTER, backend = 
NestJS. There is NO existing code to reuse; build everything fresh per the spec files.

STEP 1 — READ THE SPECS FIRST (before any code):
1. CLAUDE.md         → full spec: principles, Flutter + NestJS stack, zones+pricing, data 
                       model, backend API, flows, phase build order.
2. DESIGN.md         → the UI/UX design system; follow it for every screen.
3. zones-pricing.md  → the zone map + Share/Reserve fare tables (source of truth for fares).

Then give me a SHORT summary (12–15 lines) proving you understood:
- core principles (zero-commission, fixed pricing, Hindi-first + voice, safety)
- the stack (Flutter: Riverpod/go_router/dio/socket_io_client/firebase/flutter_map; 
  backend: NestJS + Prisma + PostGIS + Socket.IO)
- the 5 zones and how Reserve/Share pricing works
- the phase order
STOP and wait for my "go" before Phase 0.

STEP 2 — BUILD PHASE BY PHASE (CLAUDE.md Section 8). After EACH phase: stop, tell me exactly 
what to test, and wait for my confirmation before the next.
- PHASE 0: Scaffold backend (NestJS + Prisma + PostGIS, listens on 0.0.0.0:4000, CORS) and 
  the Flutter workspace (core package + user_app + driver_app) + Dev Settings (runtime API URL).
- PHASE 1: Auth (firebase phone → JWT) + user/driver profiles + pricing/zone helpers.
- PHASE 2: Reserve ride flow end-to-end + Socket.IO + FCM (zones A/B/C) — the thin slice.
- PHASE 3: Safety (SOS, share link, ratings/complaints).
- PHASE 4: Share mode + zones D/E + subscription.
- PHASE 5: Polish + voice + icon/splash + apk build + README.

STEP 3 — GUARDRAILS:
- Everything new; no legacy code.
- Maps = OpenStreetMap (flutter_map), never Google Maps paid APIs.
- Fares only from zones-pricing.md / CLAUDE.md Section 3. No surge, no bidding.
- Hindi-first, big buttons, voice for the driver, no driver typing.
- Backend must listen on 0.0.0.0:4000 with CORS; Dev Settings must let me change the API 
  base URL at runtime (a physical phone needs the PC LAN IP, e.g. http://192.168.1.12:4000).
- Driver go-online must send GPS location (POST /drivers/me/location) BEFORE going online.
- Never show raw API responses/HTML to users — clean Hindi error dialogs only.
- One phase at a time. Ask before any paid service or deviation from specs.

Start with STEP 1 only: read the specs, give the summary, then wait for "go".
```

---

## Reminders for you (Hearterz)

1. **Logo + app icon ready hain** (`rickbo-logo.png`, `rickbo-icon-1024.png`). Phase 5 mein 
   `rickbo-icon-1024.png` ko app icon set karna; saffron bg #FF7A18.
2. **Physical phone pe test** karega to Dev Settings mein `http://192.168.1.12:4000` daalna 
   (apna PC LAN IP). Backend `0.0.0.0:4000` pe chalna chahiye + Windows firewall mein Node 
   ko allow karna.
3. **Firebase project** ek naya banana padega (phone auth + FCM) — Phase 0/1 mein Claude 
   Code bata dega kaunsi config files chahiye (google-services.json etc.).
4. **Phase-by-phase** chalना — Phase 0 → test → Phase 1. "Sab bana do" ek saath mat bolna.
```
