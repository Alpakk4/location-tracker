-- Flag synthetic (red herring) visits and journeys injected for sensitivity/specificity analysis.
ALTER TABLE "public"."diary_visits"
  ADD COLUMN IF NOT EXISTS "is_synthetic" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."diary_journeys"
  ADD COLUMN IF NOT EXISTS "is_synthetic" boolean NOT NULL DEFAULT false;
