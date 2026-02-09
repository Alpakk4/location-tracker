-- Create diary_completed table for storing user-annotated diary entries

CREATE TABLE IF NOT EXISTS "public"."diary_completed" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "source_entryid" "uuid" NOT NULL,
    "deviceid" character varying NOT NULL,
    "diary_date" date NOT NULL,
    "primary_type" "text",
    "activity_label" "text",
    "confirmed_place" boolean NOT NULL,
    "confirmed_activity" boolean NOT NULL,
    "user_context" "text",
    "motion_type" "jsonb",
    "created_at" timestamp with time zone DEFAULT "timezone"('gmt'::"text", "now"()) NOT NULL
);

ALTER TABLE "public"."diary_completed" OWNER TO "postgres";

ALTER TABLE ONLY "public"."diary_completed"
    ADD CONSTRAINT "diary_completed_pkey" PRIMARY KEY ("id");

ALTER TABLE "public"."diary_completed" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anonymous inserts" ON "public"."diary_completed"
    FOR INSERT TO "authenticated", "anon", "service_role" WITH CHECK (true);

GRANT ALL ON TABLE "public"."diary_completed" TO "anon";
GRANT ALL ON TABLE "public"."diary_completed" TO "authenticated";
GRANT ALL ON TABLE "public"."diary_completed" TO "service_role";
