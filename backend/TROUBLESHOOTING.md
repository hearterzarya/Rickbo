# Backend troubleshooting

Hit a wall? Look here first. Most issues are deployment-environment
quirks, not code bugs.

## Hindi text stored as `???? ???????` (or any non-ASCII turns into `?`)

**Symptom:** you POST a Hindi name in the request body, but it comes back
as a string of `?` characters in the JSON response. The same name shows
up as `???? ???????` on the public share page (`/s/:token`). All ASCII
text (phone numbers, rickshaw numbers, fare) is fine.

**Root cause:** the Postgres session the app received has
`client_encoding` set to `SQL_ASCII` (or `LATIN1`, `WIN1252`, etc.)
instead of `UTF8`. Any multi-byte UTF-8 sequence gets silently replaced
with `?` on insert.

**Why this happens on Railway:** Railway's managed Postgres is normally
fine, but the connection pooler (PgBouncer) sometimes hands out
connections whose session state was set by an earlier client. Without
explicit `client_encoding=UTF8` in the connection URL, the session keeps
whatever the previous tenant left behind.

**Fix:** add these query params to your `DATABASE_URL`:

```
?client_encoding=UTF8&pgbouncer=true&connection_limit=1
```

Example (with PgBouncer params appended):

```
DATABASE_URL="postgresql://user:pass@host:5432/rickbo?client_encoding=UTF8&pgbouncer=true&connection_limit=1"
```

**How to verify after deploying:**

```sql
-- Run this in any SQL console connected to your database:
SELECT current_setting('client_encoding');
-- Expected: UTF8 (or UNICODE on older PG)
-- If you see SQL_ASCII or LATIN1, the env var above is missing.
```

`PrismaService` will also log a warning on startup if
`client_encoding` is not UTF-8. Look for this line in the deploy logs:

```
[PrismaService] Postgres client_encoding=UTF8        ← good
[PrismaService] Postgres client_encoding=SQL_ASCII    ← bad, will warn
```

**Cleanup if you have `?` in the DB already:** the corrupted rows can't
be auto-recovered (the original bytes are gone). Either:
1. Have the driver re-enter their name in the app, **after** the env
   var is fixed.
2. Or run a one-off SQL `UPDATE` setting them to a Latin transliteration.

## PgBouncer + Prisma prepared-statement errors

**Symptom:** at high traffic the backend logs
`prepared statement "s0" already exists` or
`Error: Invalid prepared statement`.

**Fix:** same env var — `pgbouncer=true` switches Prisma from prepared
statement mode to transaction mode, which PgBouncer requires.

## `PostGIS not found`

**Symptom:** first migration fails with
`type "geography" does not exist`.

**Fix:** enable the PostGIS extension on the database (run once):

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Neon: SQL console → run the above.
Railway: same — Railway's Postgres supports it on the free tier.

## `401 Unauthorized` on every API call

**Symptom:** even `POST /auth/test-otp/verify` works (returns a token),
but every subsequent call says 401.

**Root cause:** the JWT was issued by a backend with one `JWT_SECRET`
and the verifier is running with a different one. Usually happens
after a redeploy where the env was re-injected from a stale value.

**Fix:** check `JWT_SECRET` in the deployed env. Restart the service.
Tokens issued before the fix are now invalid — the user has to log in
again.

## `dio: connection refused` on emulator

**Symptom:** Flutter app on Android emulator shows
`Connection refused` on every request, but the same backend works from
your laptop's browser.

**Fix:** in the app, open Dev Settings and set the API URL to
`http://10.0.2.2:4000` — `10.0.2.2` is the emulator's special hostname
for the host machine's `localhost`.

## Hindi TTS speaks nothing

**Symptom:** the driver's phone plays no audio on "सवारी है".

**Fix:** on the Android device:
- Settings → Languages → add Hindi (हिन्दी)
- Install Google TTS engine if not already
- Settings → Accessibility → Text-to-speech output → set Google TTS as
  preferred engine

## Backend times out on cold start (Railway)

**Symptom:** first request after a deploy takes 20+ seconds; subsequent
ones are fast.

**Why:** Railway spins the service down after ~5 min of zero traffic on
the free tier. The first request after that pays the cold-start cost.

**Fix:** upgrade to a paid plan, or accept the cold-start (most users
won't notice because their app opens with a splash screen).

## `npx prisma generate` fails during build

**Symptom:** Railway build log shows
`Error: Cannot find module '@prisma/client'`.

**Fix:** the build runs `prisma generate` before `nest build`. If that
step fails, the generated client isn't there for the rest of the build.
Look for the actual error in the build log — usually it's a
DATABASE_URL issue (e.g. wrong host, or the DB was deleted).
