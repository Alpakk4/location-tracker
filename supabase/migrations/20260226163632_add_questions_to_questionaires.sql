-- DROP COLUMNS
alter table "public"."gcplar_responses" drop column "complex_score_total";

alter table "public"."gcplar_responses" drop column "simple_score_total";
-- ADD NEW COLUMNS CONTAINING QUESTIONS
alter table "public"."gcplar_responses" add column "attend_live_performance" smallint;

alter table "public"."gcplar_responses" add column "attend_museum_gallery" smallint;

alter table "public"."gcplar_responses" add column "browse_internet" smallint;

alter table "public"."gcplar_responses" add column "dentist" smallint;

alter table "public"."gcplar_responses" add column "disco_nightclub" smallint;

alter table "public"."gcplar_responses" add column "doctor_gp" smallint;

alter table "public"."gcplar_responses" add column "exercise_class" smallint;

alter table "public"."gcplar_responses" add column "go_to_friends_house" smallint;

alter table "public"."gcplar_responses" add column "high_street_store" smallint;

alter table "public"."gcplar_responses" add column "holiday_daytrip" smallint;

alter table "public"."gcplar_responses" add column "hospital" smallint;

alter table "public"."gcplar_responses" add column "local_shop_post_office" smallint;

alter table "public"."gcplar_responses" add column "look_at_books_magazines" smallint;

alter table "public"."gcplar_responses" add column "participate_in_performance_arts" smallint;

alter table "public"."gcplar_responses" add column "participate_in_sport" smallint;

alter table "public"."gcplar_responses" add column "play_games_with_others" smallint;

alter table "public"."gcplar_responses" add column "restaurant_cafe" smallint;

alter table "public"."gcplar_responses" add column "score_total" real;

alter table "public"."gcplar_responses" add column "social_club_society" smallint;

alter table "public"."gcplar_responses" add column "social_networking_internet" smallint;

alter table "public"."gcplar_responses" add column "spend_time_with_family" smallint;

alter table "public"."gcplar_responses" add column "supermarket_large_retail" smallint;

alter table "public"."gcplar_responses" add column "swimming" smallint;
-- ADD GENERATED COLUMNS
alter table "public"."gcplar_responses" add column "active_leisure_subscore" smallint generated always as ((((COALESCE((swimming)::integer, 0) + COALESCE((participate_in_sport)::integer, 0)) + COALESCE((exercise_class)::integer, 0)) + COALESCE((participate_in_performance_arts)::integer, 0))) stored;

alter table "public"."gcplar_responses" add column "enrichment_subscore" smallint generated always as (((COALESCE((attend_museum_gallery)::integer, 0) + COALESCE((attend_live_performance)::integer, 0)) + COALESCE((holiday_daytrip)::integer, 0))) stored;

alter table "public"."gcplar_responses" add column "health_subscore" smallint generated always as (((COALESCE((hospital)::integer, 0) + COALESCE((doctor_gp)::integer, 0)) + COALESCE((dentist)::integer, 0))) stored;

alter table "public"."gcplar_responses" add column "indoor_leisure_subscore" smallint generated always as ((COALESCE((play_games_with_others)::integer, 0) + COALESCE((look_at_books_magazines)::integer, 0))) stored;

alter table "public"."gcplar_responses" add column "retail_subscore" smallint generated always as ((((COALESCE((high_street_store)::integer, 0) + COALESCE((supermarket_large_retail)::integer, 0)) + COALESCE((local_shop_post_office)::integer, 0)) + COALESCE((restaurant_cafe)::integer, 0))) stored;

alter table "public"."gcplar_responses" add column "social_engagement_subscore" smallint generated always as (((COALESCE((social_networking_internet)::integer, 0) + COALESCE((browse_internet)::integer, 0)) + COALESCE((spend_time_with_family)::integer, 0))) stored;

alter table "public"."gcplar_responses" add column "social_leisure_subscore" smallint generated always as (((COALESCE((social_club_society)::integer, 0) + COALESCE((disco_nightclub)::integer, 0)) + COALESCE((go_to_friends_house)::integer, 0))) stored;

alter table "public"."gcplar_responses" add column "total_score" smallint generated always as ((((((((((((((((((((((COALESCE((attend_museum_gallery)::integer, 0) + COALESCE((attend_live_performance)::integer, 0)) + COALESCE((holiday_daytrip)::integer, 0)) + COALESCE((swimming)::integer, 0)) + COALESCE((participate_in_sport)::integer, 0)) + COALESCE((exercise_class)::integer, 0)) + COALESCE((participate_in_performance_arts)::integer, 0)) + COALESCE((social_networking_internet)::integer, 0)) + COALESCE((browse_internet)::integer, 0)) + COALESCE((spend_time_with_family)::integer, 0)) + COALESCE((play_games_with_others)::integer, 0)) + COALESCE((look_at_books_magazines)::integer, 0)) + COALESCE((social_club_society)::integer, 0)) + COALESCE((disco_nightclub)::integer, 0)) + COALESCE((go_to_friends_house)::integer, 0)) + COALESCE((hospital)::integer, 0)) + COALESCE((doctor_gp)::integer, 0)) + COALESCE((dentist)::integer, 0)) + COALESCE((high_street_store)::integer, 0)) + COALESCE((supermarket_large_retail)::integer, 0)) + COALESCE((local_shop_post_office)::integer, 0)) + COALESCE((restaurant_cafe)::integer, 0))) stored;


alter table "public"."whodas_responses" drop column "score_total";

alter table "public"."whodas_responses" add column "d1_1" smallint;

alter table "public"."whodas_responses" add column "d1_2" smallint;

alter table "public"."whodas_responses" add column "d1_3" smallint;

alter table "public"."whodas_responses" add column "d1_4" smallint;

alter table "public"."whodas_responses" add column "d1_5" smallint;

alter table "public"."whodas_responses" add column "d1_6" smallint;

alter table "public"."whodas_responses" add column "d2_1" smallint;

alter table "public"."whodas_responses" add column "d2_2" smallint;

alter table "public"."whodas_responses" add column "d2_3" smallint;

alter table "public"."whodas_responses" add column "d2_4" smallint;

alter table "public"."whodas_responses" add column "d2_5" smallint;

alter table "public"."whodas_responses" add column "d3_1" smallint;

alter table "public"."whodas_responses" add column "d3_2" smallint;

alter table "public"."whodas_responses" add column "d3_3" smallint;

alter table "public"."whodas_responses" add column "d3_4" smallint;

alter table "public"."whodas_responses" add column "d4_1" smallint;

alter table "public"."whodas_responses" add column "d4_2" smallint;

alter table "public"."whodas_responses" add column "d4_3" smallint;

alter table "public"."whodas_responses" add column "d4_4" smallint;

alter table "public"."whodas_responses" add column "d4_5" smallint;

alter table "public"."whodas_responses" add column "d5_1" smallint;

alter table "public"."whodas_responses" add column "d5_2" smallint;

alter table "public"."whodas_responses" add column "d5_3" smallint;

alter table "public"."whodas_responses" add column "d5_4" smallint;

alter table "public"."whodas_responses" add column "d5_5" smallint;

alter table "public"."whodas_responses" add column "d5_6" smallint;

alter table "public"."whodas_responses" add column "d5_7" smallint;

alter table "public"."whodas_responses" add column "d5_8" smallint;

alter table "public"."whodas_responses" add column "d6_1" smallint;

alter table "public"."whodas_responses" add column "d6_2" smallint;

alter table "public"."whodas_responses" add column "d6_3" smallint;

alter table "public"."whodas_responses" add column "d6_4" smallint;

alter table "public"."whodas_responses" add column "d6_5" smallint;

alter table "public"."whodas_responses" add column "d6_6" smallint;

alter table "public"."whodas_responses" add column "d6_7" smallint;

alter table "public"."whodas_responses" add column "d6_8" smallint;

alter table "public"."whodas_responses" add column "getting_along_people_domain_score" smallint generated always as (((((COALESCE((d4_1)::integer, 0) + COALESCE((d4_2)::integer, 0)) + COALESCE((d4_3)::integer, 0)) + COALESCE((d4_4)::integer, 0)) + COALESCE((d4_5)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "getting_around_domain_score" smallint generated always as (((((COALESCE((d2_1)::integer, 0) + COALESCE((d2_2)::integer, 0)) + COALESCE((d2_3)::integer, 0)) + COALESCE((d2_4)::integer, 0)) + COALESCE((d2_5)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "household_activities_domain_score" smallint generated always as ((((COALESCE((d5_1)::integer, 0) + COALESCE((d5_2)::integer, 0)) + COALESCE((d5_3)::integer, 0)) + COALESCE((d5_4)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "participation_domain_score" smallint generated always as ((((((((COALESCE((d6_1)::integer, 0) + COALESCE((d6_2)::integer, 0)) + COALESCE((d6_3)::integer, 0)) + COALESCE((d6_4)::integer, 0)) + COALESCE((d6_5)::integer, 0)) + COALESCE((d6_6)::integer, 0)) + COALESCE((d6_7)::integer, 0)) + COALESCE((d6_8)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "school_work_activites_domain_score" smallint generated always as ((((COALESCE((d5_5)::integer, 0) + COALESCE((d5_6)::integer, 0)) + COALESCE((d5_7)::integer, 0)) + COALESCE((d5_8)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "selfcare_domain_score" smallint generated always as ((((COALESCE((d3_1)::integer, 0) + COALESCE((d3_2)::integer, 0)) + COALESCE((d3_3)::integer, 0)) + COALESCE((d3_4)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "total_simple_score" smallint generated always as ((((((((((((((((((((((((((((((((((((COALESCE((d1_1)::integer, 0) + COALESCE((d1_2)::integer, 0)) + COALESCE((d1_3)::integer, 0)) + COALESCE((d1_4)::integer, 0)) + COALESCE((d1_5)::integer, 0)) + COALESCE((d1_6)::integer, 0)) + COALESCE((d2_1)::integer, 0)) + COALESCE((d2_2)::integer, 0)) + COALESCE((d2_3)::integer, 0)) + COALESCE((d2_4)::integer, 0)) + COALESCE((d2_5)::integer, 0)) + COALESCE((d3_1)::integer, 0)) + COALESCE((d3_2)::integer, 0)) + COALESCE((d3_3)::integer, 0)) + COALESCE((d3_4)::integer, 0)) + COALESCE((d4_1)::integer, 0)) + COALESCE((d4_2)::integer, 0)) + COALESCE((d4_3)::integer, 0)) + COALESCE((d4_4)::integer, 0)) + COALESCE((d4_5)::integer, 0)) + COALESCE((d5_1)::integer, 0)) + COALESCE((d5_2)::integer, 0)) + COALESCE((d5_3)::integer, 0)) + COALESCE((d5_4)::integer, 0)) + COALESCE((d5_5)::integer, 0)) + COALESCE((d5_6)::integer, 0)) + COALESCE((d5_7)::integer, 0)) + COALESCE((d5_8)::integer, 0)) + COALESCE((d6_1)::integer, 0)) + COALESCE((d6_2)::integer, 0)) + COALESCE((d6_3)::integer, 0)) + COALESCE((d6_4)::integer, 0)) + COALESCE((d6_5)::integer, 0)) + COALESCE((d6_6)::integer, 0)) + COALESCE((d6_7)::integer, 0)) + COALESCE((d6_8)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "understand_communicate_domain_score" smallint generated always as ((((((COALESCE((d1_1)::integer, 0) + COALESCE((d1_2)::integer, 0)) + COALESCE((d1_3)::integer, 0)) + COALESCE((d1_4)::integer, 0)) + COALESCE((d1_5)::integer, 0)) + COALESCE((d1_6)::integer, 0))) stored;

alter table "public"."whodas_responses" add column "whodas_complex_score" double precision;

alter table "public"."whodas_responses" add column "whodas_percent_score" double precision generated always as (((((((((((((((((((((((((((((((((((((((COALESCE((d1_1)::integer, 0) + COALESCE((d1_2)::integer, 0)) + COALESCE((d1_3)::integer, 0)) + COALESCE((d1_4)::integer, 0)) + COALESCE((d1_5)::integer, 0)) + COALESCE((d1_6)::integer, 0)) + COALESCE((d2_1)::integer, 0)) + COALESCE((d2_2)::integer, 0)) + COALESCE((d2_3)::integer, 0)) + COALESCE((d2_4)::integer, 0)) + COALESCE((d2_5)::integer, 0)) + COALESCE((d3_1)::integer, 0)) + COALESCE((d3_2)::integer, 0)) + COALESCE((d3_3)::integer, 0)) + COALESCE((d3_4)::integer, 0)) + COALESCE((d4_1)::integer, 0)) + COALESCE((d4_2)::integer, 0)) + COALESCE((d4_3)::integer, 0)) + COALESCE((d4_4)::integer, 0)) + COALESCE((d4_5)::integer, 0)) + COALESCE((d5_1)::integer, 0)) + COALESCE((d5_2)::integer, 0)) + COALESCE((d5_3)::integer, 0)) + COALESCE((d5_4)::integer, 0)) + COALESCE((d5_5)::integer, 0)) + COALESCE((d5_6)::integer, 0)) + COALESCE((d5_7)::integer, 0)) + COALESCE((d5_8)::integer, 0)) + COALESCE((d6_1)::integer, 0)) + COALESCE((d6_2)::integer, 0)) + COALESCE((d6_3)::integer, 0)) + COALESCE((d6_4)::integer, 0)) + COALESCE((d6_5)::integer, 0)) + COALESCE((d6_6)::integer, 0)) + COALESCE((d6_7)::integer, 0)) + COALESCE((d6_8)::integer, 0)))::numeric / 144.0) * (100)::numeric)) stored;

alter table "public"."gcplar_responses" add constraint "gcplar_responses_score_total_check" CHECK ((score_total >= (0.0)::double precision)) not valid;

alter table "public"."gcplar_responses" validate constraint "gcplar_responses_score_total_check";


