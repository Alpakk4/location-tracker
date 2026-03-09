-- Add auth_uid to device_registry for JWT link flow.
-- When a device is linked via link-device, we store the Supabase Auth user id (auth.uid()) here.
-- Decommission / unlink sets this to null or deletes the row so the device_id can be reused.
alter table "public"."device_registry"
  add column if not exists "auth_uid" uuid;

comment on column "public"."device_registry"."auth_uid" is 'Supabase Auth user id (auth.uid()) linked to this device; null until linked, cleared on decommission.';
