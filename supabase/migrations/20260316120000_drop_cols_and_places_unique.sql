-- Drop raw coordinate and display-name columns from locationsvisitednew
ALTER TABLE public.locationsvisitednew
  DROP COLUMN IF EXISTS latitude,
  DROP COLUMN IF EXISTS longitude,
  DROP COLUMN IF EXISTS closest_place;

-- Promote the existing btree index to a UNIQUE constraint for upsert support
DROP INDEX IF EXISTS public.places_hashed_id_idx;
ALTER TABLE public.places
  ADD CONSTRAINT places_hashed_google_id_unique UNIQUE (hashed_google_id);
