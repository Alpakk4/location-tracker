# decommission-device

Admin-only edge function to unlink a device so its `device_id` can be reused. Automates:

1. **Revoke JWT** (optional): Delete the Supabase Auth user so the linked session is invalid immediately.
2. **Clear link or delete row**: Set `auth_uid = null` on the device_registry row, or delete the row.

## Setup

- Set **ADMIN_SECRET** in your Supabase project (Dashboard → Project Settings → Edge Functions → Secrets, or `supabase secrets set ADMIN_SECRET=your-secret`). Use a strong random value; only you should know it.
- Ensure **device_registry** has the **auth_uid** column (migration `20260309120000_add_auth_uid_to_device_registry.sql`).

## Request

- **Method:** POST
- **URL:** `https://<project-ref>.supabase.co/functions/v1/decommission-device`
- **Headers:**
  - `Content-Type: application/json`
  - `X-Admin-Secret: <your ADMIN_SECRET value>`
  - `Authorization: Bearer <anon key>` (and `apikey: <anon key>` if required by your project)
- **Body:**
  - `deviceId` (string, required): The device_id to decommission.
  - `deleteRow` (boolean, optional, default `false`): If `true`, delete the row from device_registry. If `false`, only set `auth_uid = null` (row remains; device_id can be linked again).
  - `revokeJwt` (boolean, optional, default `true`): If `true`, delete the linked Auth user so the JWT is invalid immediately. If `false`, only clear the link (old JWT may still work until expiry, but will have no linked device).

## Examples

**Clear link only (device_id can be re-linked; keep row):**
```json
{ "deviceId": "device-abc-123" }
```
or explicitly:
```json
{ "deviceId": "device-abc-123", "deleteRow": false, "revokeJwt": true }
```

**Clear link and revoke JWT, but keep the row:**
Same as above (default).

**Delete the row (full remove; re-use requires re-inserting the row):**
```json
{ "deviceId": "device-abc-123", "deleteRow": true, "revokeJwt": true }
```

**Clear link but do not revoke JWT (old app session stays valid until token expiry):**
```json
{ "deviceId": "device-abc-123", "revokeJwt": false }
```

## Response

- **200:** `{ "ok": true, "result": { "deviceId": "...", "authUidRevoked": true|false, "rowCleared": true|false, "rowDeleted": true|false } }`
- **401:** Missing or invalid `X-Admin-Secret`
- **404:** Device not found in registry
- **500:** Server error (see logs for details)
