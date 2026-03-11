# Local testing: security flow (Option B + error sanitization)

Use this checklist to verify the current behaviour locally before committing.

## 1. Start Supabase and functions

```bash
cd /path/to/location-tracker
supabase start
```

Then serve edge functions (in a separate terminal):

```bash
supabase functions serve
```

- `supabase start` runs the local DB and API (e.g. `http://127.0.0.1:54321`). It injects `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` when you invoke functions.
- `supabase functions serve` runs all functions; requests go through the local API.

Optional: if you need extra env vars (e.g. for **ping**), create `supabase/.env.local` (do not commit) and run:

```bash
supabase functions serve --env-file supabase/.env.local
```

Required for **ping** to succeed:

- `MAPS_API` – Google Places API key (or ping will return 503).

Optional for **ping**:

- `DEFAULT_HOME_LAT`, `DEFAULT_HOME_LONG` – used when the client does not send home. If unset, ping uses fallback `51.503349370657986`, `-0.0868719398915672`.

Required for **decommission-device** (only if you test that function):

- `ADMIN_SECRET` – value you send in `X-Admin-Secret` header.

## 2. Put a test device in `device_registry`

**ping** and **backfill-reframe-home** return **403 Unknown device** unless the request `uid` / `deviceId` exists in `device_registry`.

In Supabase Studio (e.g. http://127.0.0.1:54323) → SQL Editor, or via `psql`:

```sql
-- One-time: insert a test device (adjust device_id if your schema has constraints)
INSERT INTO public.device_registry (device_id)
VALUES ('test-device-local-001')
ON CONFLICT (device_id) DO NOTHING;
```

Use that same id (e.g. `test-device-local-001`) as the device/uid when calling the APIs or when testing from the iOS app.

## 3. Test device validation (403 for unknown device)

- **ping**  
  POST to `http://127.0.0.1:54321/functions/v1/ping` with body including `"uid": "unknown-device-999"`.  
  **Expect:** `403` and `{ "error": "Unknown device" }` (no `detail` or DB message).

- **backfill-reframe-home**  
  POST to `http://127.0.0.1:54321/functions/v1/backfill-reframe-home` with body  
  `{ "deviceId": "unknown-device-999", "user_home_lat": 0, "user_home_long": 0 }`.  
  **Expect:** `403` and `{ "error": "Unknown device" }`.

## 4. Test success path (known device)

- **ping**  
  Use a valid body with `"uid": "test-device-local-001"` (and valid `lat`, `long`, `motion`, etc.).  
  **Expect:** `201` and `{ "status": "ok" }` (and a row in `locationsvisitednew` if MAPS_API is set).

- **backfill-reframe-home**  
  Use `"deviceId": "test-device-local-001"` and valid coordinates.  
  **Expect:** `200` and `{ "updated": N }`.

## 5. Test error sanitization (no leaks)

- **ping**  
  Send a body that will cause an insert failure (e.g. omit a required field so validation fails, or use a device that exists but cause a DB error if you can).  
  **Expect:** Response body has only a generic message (e.g. `{ "error": "insert failed" }` or `{ "error": "..." }`), and **no** `detail`, `details`, or raw `error.message`.

- **diary-submit**  
  Send invalid or already-submitted diary data so the RPC fails.  
  **Expect:** `500` with something like `{ "error": "Diary submission failed" }` or `{ "error": "Internal Server Error" }`, and **no** raw DB/RPC message in the body.

Check server logs for the real error (e.g. in the terminal where `supabase functions serve` is running); clients should never see those details.

## 6. Test from the iOS app (optional)

- Point the app at your local Supabase (local API URL and anon key in your app config / env).
- Use the same **device ID** you inserted in step 2 (e.g. `test-device-local-001`) when onboarding or in the app’s stored UID.
- Run through: ping, diary load, diary submit. You should get normal behaviour; unknown device would show as 403 from the backend.

## 7. Quick curl examples

Replace `YOUR_ANON_KEY` with the anon key from `supabase status` (or Studio).

```bash
# 403 – unknown device (ping)
curl -s -X POST "http://127.0.0.1:54321/functions/v1/ping" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"uid":"unknown-999","lat":0,"long":0,"motion":{"motion":"still","confidence":"low"}}'

# 403 – unknown device (backfill-reframe-home)
curl -s -X POST "http://127.0.0.1:54321/functions/v1/backfill-reframe-home" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"unknown-999","user_home_lat":0,"user_home_long":0}'
```

After you add `test-device-local-001` to `device_registry`, repeat with `"uid":"test-device-local-001"` and valid payload to confirm 201/200.

---

**Summary:** Ensure (1) a test device exists in `device_registry`, (2) unknown devices get 403 with a generic message, (3) error responses never include `detail`/`details`/raw DB messages, and (4) `MAPS_API` is set if you want ping to complete successfully. Then you’re good to commit.
