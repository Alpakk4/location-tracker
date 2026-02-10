-- Normalize diary schema: diary_completed -> diaries + diary_visits + diary_visit_entries
-- This migration creates the three normalized tables, migrates existing data, and drops
-- the old diary_completed table.

BEGIN;

-- =========================================================================
-- 1. Create new tables
-- =========================================================================

-- One diary per device per day
CREATE TABLE IF NOT EXISTS "public"."diaries" (
    "id"           uuid DEFAULT gen_random_uuid() NOT NULL,
    "deviceid"     character varying NOT NULL,
    "diary_date"   date NOT NULL,
    "created_at"   timestamp with time zone DEFAULT timezone('gmt'::text, now()) NOT NULL,
    "submitted_at" timestamp with time zone,
    CONSTRAINT diaries_pkey PRIMARY KEY (id),
    CONSTRAINT diaries_device_date_unique UNIQUE (deviceid, diary_date)
);

ALTER TABLE "public"."diaries" OWNER TO "postgres";

-- Individual visit clusters within a diary
CREATE TABLE IF NOT EXISTS "public"."diary_visits" (
    "id"                  uuid DEFAULT gen_random_uuid() NOT NULL,
    "diary_id"            uuid NOT NULL,
    "visit_id"            text NOT NULL,
    "primary_type"        text,
    "other_types"         text[],
    "motion_type"         jsonb,
    "visit_confidence"    text,
    "ping_count"          integer,
    "cluster_duration_s"  integer,
    "started_at"          timestamp with time zone,
    "ended_at"            timestamp with time zone,
    "activity_label"      text,
    "confirmed_place"     boolean,
    "confirmed_activity"  boolean,
    "user_context"        text,
    "created_at"          timestamp with time zone DEFAULT timezone('gmt'::text, now()) NOT NULL,
    CONSTRAINT diary_visits_pkey PRIMARY KEY (id),
    CONSTRAINT diary_visits_diary_id_fkey FOREIGN KEY (diary_id)
        REFERENCES "public"."diaries" (id) ON DELETE CASCADE,
    CONSTRAINT diary_visits_diary_visit_unique UNIQUE (diary_id, visit_id)
);

ALTER TABLE "public"."diary_visits" OWNER TO "postgres";

-- Join table linking visits to raw pings in locationsvisitednew
CREATE TABLE IF NOT EXISTS "public"."diary_visit_entries" (
    "id"                  uuid DEFAULT gen_random_uuid() NOT NULL,
    "diary_visit_id"      uuid NOT NULL,
    "entry_id"            uuid NOT NULL,
    "position_in_cluster" integer NOT NULL DEFAULT 0,
    CONSTRAINT diary_visit_entries_pkey PRIMARY KEY (id),
    CONSTRAINT diary_visit_entries_visit_fkey FOREIGN KEY (diary_visit_id)
        REFERENCES "public"."diary_visits" (id) ON DELETE CASCADE,
    CONSTRAINT diary_visit_entries_entry_fkey FOREIGN KEY (entry_id)
        REFERENCES "public"."locationsvisitednew" (entryid) ON DELETE CASCADE,
    CONSTRAINT diary_visit_entries_unique UNIQUE (diary_visit_id, entry_id)
);

ALTER TABLE "public"."diary_visit_entries" OWNER TO "postgres";

-- =========================================================================
-- 2. Indexes for common query patterns
-- =========================================================================

CREATE INDEX diary_visits_diary_id_idx ON "public"."diary_visits" USING btree (diary_id);
CREATE INDEX diary_visit_entries_visit_id_idx ON "public"."diary_visit_entries" USING btree (diary_visit_id);
CREATE INDEX diary_visit_entries_entry_id_idx ON "public"."diary_visit_entries" USING btree (entry_id);

-- =========================================================================
-- 3. Enable RLS
-- =========================================================================

ALTER TABLE "public"."diaries" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."diary_visits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."diary_visit_entries" ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- 4. RLS policies (permissive, matching existing pattern)
-- =========================================================================

-- diaries
CREATE POLICY "Allow anonymous selects" ON "public"."diaries"
    AS permissive FOR SELECT TO authenticated, anon, service_role USING (true);

CREATE POLICY "Allow anonymous inserts" ON "public"."diaries"
    AS permissive FOR INSERT TO authenticated, anon, service_role WITH CHECK (true);

CREATE POLICY "Allow anonymous updates" ON "public"."diaries"
    AS permissive FOR UPDATE TO authenticated, anon, service_role USING (true) WITH CHECK (true);

-- diary_visits
CREATE POLICY "Allow anonymous selects" ON "public"."diary_visits"
    AS permissive FOR SELECT TO authenticated, anon, service_role USING (true);

CREATE POLICY "Allow anonymous inserts" ON "public"."diary_visits"
    AS permissive FOR INSERT TO authenticated, anon, service_role WITH CHECK (true);

CREATE POLICY "Allow anonymous updates" ON "public"."diary_visits"
    AS permissive FOR UPDATE TO authenticated, anon, service_role USING (true) WITH CHECK (true);

-- diary_visit_entries
CREATE POLICY "Allow anonymous selects" ON "public"."diary_visit_entries"
    AS permissive FOR SELECT TO authenticated, anon, service_role USING (true);

CREATE POLICY "Allow anonymous inserts" ON "public"."diary_visit_entries"
    AS permissive FOR INSERT TO authenticated, anon, service_role WITH CHECK (true);

-- =========================================================================
-- 5. Grants (matching existing pattern)
-- =========================================================================

GRANT ALL ON TABLE "public"."diaries" TO "anon";
GRANT ALL ON TABLE "public"."diaries" TO "authenticated";
GRANT ALL ON TABLE "public"."diaries" TO "service_role";

GRANT ALL ON TABLE "public"."diary_visits" TO "anon";
GRANT ALL ON TABLE "public"."diary_visits" TO "authenticated";
GRANT ALL ON TABLE "public"."diary_visits" TO "service_role";

GRANT ALL ON TABLE "public"."diary_visit_entries" TO "anon";
GRANT ALL ON TABLE "public"."diary_visit_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."diary_visit_entries" TO "service_role";

-- =========================================================================
-- 6. Migrate existing data from diary_completed
-- =========================================================================

-- 6a. Create one diary row per unique (deviceid, diary_date)
INSERT INTO "public"."diaries" (deviceid, diary_date, created_at)
SELECT DISTINCT ON (deviceid, diary_date)
    deviceid,
    diary_date,
    MIN(created_at) AS created_at
FROM "public"."diary_completed"
GROUP BY deviceid, diary_date
ON CONFLICT (deviceid, diary_date) DO NOTHING;

-- 6b. Create one diary_visits row per diary_completed row
INSERT INTO "public"."diary_visits" (
    diary_id, visit_id, primary_type, other_types, motion_type,
    visit_confidence, ping_count, cluster_duration_s,
    activity_label, confirmed_place, confirmed_activity, user_context,
    created_at
)
SELECT
    d.id AS diary_id,
    dc.visit_id,
    dc.primary_type,
    dc.other_types,
    dc.motion_type,
    dc.visit_confidence,
    dc.ping_count,
    dc.cluster_duration_s,
    dc.activity_label,
    dc.confirmed_place,
    dc.confirmed_activity,
    dc.user_context,
    dc.created_at
FROM "public"."diary_completed" dc
JOIN "public"."diaries" d
    ON d.deviceid = dc.deviceid AND d.diary_date = dc.diary_date
WHERE dc.visit_id IS NOT NULL
ON CONFLICT (diary_id, visit_id) DO NOTHING;

-- 6c. Expand entry_ids arrays into diary_visit_entries rows
INSERT INTO "public"."diary_visit_entries" (diary_visit_id, entry_id, position_in_cluster)
SELECT
    dv.id AS diary_visit_id,
    unnested.entry_id::uuid,
    unnested.pos - 1 AS position_in_cluster
FROM "public"."diary_completed" dc
JOIN "public"."diaries" d
    ON d.deviceid = dc.deviceid AND d.diary_date = dc.diary_date
JOIN "public"."diary_visits" dv
    ON dv.diary_id = d.id AND dv.visit_id = dc.visit_id
CROSS JOIN LATERAL unnest(dc.entry_ids) WITH ORDINALITY AS unnested(entry_id, pos)
WHERE dc.entry_ids IS NOT NULL
  AND dc.visit_id IS NOT NULL
ON CONFLICT (diary_visit_id, entry_id) DO NOTHING;

-- =========================================================================
-- 7. Drop old table
-- =========================================================================

DROP TABLE IF EXISTS "public"."diary_completed" CASCADE;

COMMIT;
