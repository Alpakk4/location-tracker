-- Add journey tables: diary_journeys + diary_journey_entries
-- Journeys represent transport segments between consecutive high-confidence visits.
-- A ping may appear in both diary_visit_entries AND diary_journey_entries,
-- but never in two different journeys.

BEGIN;

-- =========================================================================
-- 1. Create new tables
-- =========================================================================

-- Individual journey segments within a diary
CREATE TABLE IF NOT EXISTS "public"."diary_journeys" (
    "id"                      uuid DEFAULT gen_random_uuid() NOT NULL,
    "diary_id"                uuid NOT NULL,
    "journey_id"              text NOT NULL,
    "from_visit_id"           text,
    "to_visit_id"             text,
    "primary_transport"       text,
    "transport_proportions"   jsonb,
    "ping_count"              integer,
    "journey_duration_s"      integer,
    "started_at"              timestamp with time zone,
    "ended_at"                timestamp with time zone,
    "confirmed_transport"     boolean,
    "travel_reason"           text,
    "created_at"              timestamp with time zone DEFAULT timezone('gmt'::text, now()) NOT NULL,
    CONSTRAINT diary_journeys_pkey PRIMARY KEY (id),
    CONSTRAINT diary_journeys_diary_id_fkey FOREIGN KEY (diary_id)
        REFERENCES "public"."diaries" (id) ON DELETE CASCADE,
    CONSTRAINT diary_journeys_diary_journey_unique UNIQUE (diary_id, journey_id)
);

ALTER TABLE "public"."diary_journeys" OWNER TO "postgres";

-- Join table linking journeys to raw pings in locationsvisitednew
CREATE TABLE IF NOT EXISTS "public"."diary_journey_entries" (
    "id"                    uuid DEFAULT gen_random_uuid() NOT NULL,
    "diary_journey_id"      uuid NOT NULL,
    "entry_id"              uuid NOT NULL,
    "position_in_journey"   integer NOT NULL DEFAULT 0,
    CONSTRAINT diary_journey_entries_pkey PRIMARY KEY (id),
    CONSTRAINT diary_journey_entries_journey_fkey FOREIGN KEY (diary_journey_id)
        REFERENCES "public"."diary_journeys" (id) ON DELETE CASCADE,
    CONSTRAINT diary_journey_entries_entry_fkey FOREIGN KEY (entry_id)
        REFERENCES "public"."locationsvisitednew" (entryid) ON DELETE CASCADE,
    CONSTRAINT diary_journey_entries_unique UNIQUE (diary_journey_id, entry_id)
);

ALTER TABLE "public"."diary_journey_entries" OWNER TO "postgres";

-- =========================================================================
-- 2. Indexes for common query patterns
-- =========================================================================

CREATE INDEX diary_journeys_diary_id_idx ON "public"."diary_journeys" USING btree (diary_id);
CREATE INDEX diary_journey_entries_journey_id_idx ON "public"."diary_journey_entries" USING btree (diary_journey_id);
CREATE INDEX diary_journey_entries_entry_id_idx ON "public"."diary_journey_entries" USING btree (entry_id);

-- =========================================================================
-- 3. Enable RLS
-- =========================================================================

ALTER TABLE "public"."diary_journeys" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."diary_journey_entries" ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- 4. RLS policies (permissive, matching existing pattern)
-- =========================================================================

-- diary_journeys
CREATE POLICY "Allow anonymous selects" ON "public"."diary_journeys"
    AS permissive FOR SELECT TO authenticated, anon, service_role USING (true);

CREATE POLICY "Allow anonymous inserts" ON "public"."diary_journeys"
    AS permissive FOR INSERT TO authenticated, anon, service_role WITH CHECK (true);

CREATE POLICY "Allow anonymous updates" ON "public"."diary_journeys"
    AS permissive FOR UPDATE TO authenticated, anon, service_role USING (true) WITH CHECK (true);

-- diary_journey_entries
CREATE POLICY "Allow anonymous selects" ON "public"."diary_journey_entries"
    AS permissive FOR SELECT TO authenticated, anon, service_role USING (true);

CREATE POLICY "Allow anonymous inserts" ON "public"."diary_journey_entries"
    AS permissive FOR INSERT TO authenticated, anon, service_role WITH CHECK (true);

-- =========================================================================
-- 5. Grants (matching existing pattern)
-- =========================================================================

GRANT ALL ON TABLE "public"."diary_journeys" TO "anon";
GRANT ALL ON TABLE "public"."diary_journeys" TO "authenticated";
GRANT ALL ON TABLE "public"."diary_journeys" TO "service_role";

GRANT ALL ON TABLE "public"."diary_journey_entries" TO "anon";
GRANT ALL ON TABLE "public"."diary_journey_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."diary_journey_entries" TO "service_role";

COMMIT;
