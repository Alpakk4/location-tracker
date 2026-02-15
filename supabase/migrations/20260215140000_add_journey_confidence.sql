-- Add journey_confidence column to diary_journeys for quality scoring of journey segments.
ALTER TABLE "public"."diary_journeys"
  ADD COLUMN IF NOT EXISTS "journey_confidence" text;
