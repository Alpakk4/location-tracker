-- Re-create device FK constraints as DEFERRABLE so rename_device can
-- update the parent PK and child FKs within a single deferred transaction.

ALTER TABLE public.gcplar_responses DROP CONSTRAINT IF EXISTS fk_gcplar_device;
ALTER TABLE public.gcplar_responses ADD CONSTRAINT fk_gcplar_device
  FOREIGN KEY (device_id) REFERENCES public.device_registry(device_id)
  ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE public.whodas_responses DROP CONSTRAINT IF EXISTS fk_whodas_device;
ALTER TABLE public.whodas_responses ADD CONSTRAINT fk_whodas_device
  FOREIGN KEY (device_id) REFERENCES public.device_registry(device_id)
  ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

-- Atomically rename a device_id across all tables that reference it.
CREATE OR REPLACE FUNCTION public.rename_device(p_old_id text, p_new_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  SET CONSTRAINTS fk_gcplar_device, fk_whodas_device DEFERRED;
  UPDATE public.device_registry      SET device_id = p_new_id WHERE device_id = p_old_id;
  UPDATE public.gcplar_responses     SET device_id = p_new_id WHERE device_id = p_old_id;
  UPDATE public.whodas_responses     SET device_id = p_new_id WHERE device_id = p_old_id;
  UPDATE public.locationsvisitednew  SET deviceid  = p_new_id WHERE deviceid  = p_old_id;
  UPDATE public.diaries              SET deviceid  = p_new_id WHERE deviceid  = p_old_id;
END;
$$;

-- Delete a device and ALL associated data (manual tables first, then
-- device_registry whose CASCADE handles gcplar/whodas).
CREATE OR REPLACE FUNCTION public.purge_device(p_device_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public.diaries              WHERE deviceid  = p_device_id;
  DELETE FROM public.locationsvisitednew  WHERE deviceid  = p_device_id;
  DELETE FROM public.device_registry      WHERE device_id = p_device_id;
END;
$$;
