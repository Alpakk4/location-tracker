-- Add visit_type column to diary_visits.
-- Classifies visits by motion context: confirmed_visit, visit, brief_stop, traffic_stop.
-- Defaults to 'visit' for existing rows.

ALTER TABLE "public"."diary_visits"
    ADD COLUMN IF NOT EXISTS "visit_type" text DEFAULT 'visit';
