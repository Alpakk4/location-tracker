-- Add horizontal_accuracy column to capture GPS confidence radius (metres).
-- Negative values from CLLocation indicate invalid readings; we allow NULLs
-- for backward compatibility with rows ingested before this migration.
ALTER TABLE "public"."locationsvisitednew"
  ADD COLUMN IF NOT EXISTS "horizontal_accuracy" double precision;
