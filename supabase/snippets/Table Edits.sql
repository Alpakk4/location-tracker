/*
ALTER TABLE gcplar_responses
ADD COLUMN enrichment_subscore smallint
  GENERATED ALWAYS AS (COALESCE(attend_museum_gallery, 0) + COALESCE(attend_live_performance, 0) + COALESCE(holiday_daytrip, 0)) STORED,
  ADD COLUMN active_leisure_subscore smallint
  GENERATED ALWAYS AS (COALESCE(swimming, 0) + COALESCE(participate_in_sport, 0) + COALESCE(exercise_class, 0) + COALESCE(participate_in_performance_arts,0)) STORED,
ADD COLUMN social_engagement_subscore smallint
  GENERATED ALWAYS AS (COALESCE(social_networking_internet,0) + COALESCE(browse_internet,0) + COALESCE(spend_time_with_family,0)) STORED,
ADD COLUMN indoor_leisure_subscore smallint
  GENERATED ALWAYS AS (COALESCE(play_games_with_others,0) + COALESCE(look_at_books_magazines,0)) STORED,
ADD COLUMN social_leisure_subscore smallint
  GENERATED ALWAYS AS (COALESCE(social_club_society,0) + COALESCE(disco_nightclub,0) + COALESCE(go_to_friends_house,0)) STORED,
ADD COLUMN health_subscore smallint
  GENERATED ALWAYS AS (COALESCE(hospital,0) + COALESCE(doctor_gp,0) + COALESCE(dentist,0)) STORED,
ADD COLUMN retail_subscore smallint
  GENERATED ALWAYS AS (COALESCE(high_street_store,0) + COALESCE(supermarket_large_retail,0) + COALESCE(local_shop_post_office,0) + COALESCE(restaurant_cafe,0)) STORED;
*/
/*
ALTER TABLE gcplar_responses
ADD COLUMN total_score smallint
GENERATED ALWAYS AS (
  -- Enrichment
  COALESCE(attend_museum_gallery, 0) + COALESCE(attend_live_performance, 0) + COALESCE(holiday_daytrip, 0) +
  -- Active Leisure
  COALESCE(swimming, 0) + COALESCE(participate_in_sport, 0) + COALESCE(exercise_class, 0) + COALESCE(participate_in_performance_arts, 0) +
  -- Social Engagement
  COALESCE(social_networking_internet, 0) + COALESCE(browse_internet, 0) + COALESCE(spend_time_with_family, 0) +
  -- Indoor Leisure
  COALESCE(play_games_with_others, 0) + COALESCE(look_at_books_magazines, 0) +
  -- Social Leisure
  COALESCE(social_club_society, 0) + COALESCE(disco_nightclub, 0) + COALESCE(go_to_friends_house, 0) +
  -- Health
  COALESCE(hospital, 0) + COALESCE(doctor_gp, 0) + COALESCE(dentist, 0) +
  -- Retail
  COALESCE(high_street_store, 0) + COALESCE(supermarket_large_retail, 0) + COALESCE(local_shop_post_office, 0) + COALESCE(restaurant_cafe, 0)
) STORED;
  
*/
/*
ALTER TABLE whodas_responses
ADD COLUMN understand_communicate_domain_score smallint
  GENERATED ALWAYS AS (
    COALESCE(d1_1, 0) + 
    COALESCE(d1_2, 0) + 
    COALESCE(d1_3, 0) + 
    COALESCE(d1_4, 0) + 
    COALESCE(d1_5, 0) + 
    COALESCE(d1_6, 0)
  ) STORED,
ADD COLUMN getting_around_domain_score smallint
  GENERATED ALWAYS AS (
    COALESCE(d2_1, 0) + 
    COALESCE(d2_2, 0) + 
    COALESCE(d2_3, 0) + 
    COALESCE(d2_4, 0) + 
    COALESCE(d2_5, 0)
  ) STORED,
ADD COLUMN selfcare_domain_score smallint
  GENERATED ALWAYS AS (
    COALESCE(d3_1, 0) + 
    COALESCE(d3_2, 0) + 
    COALESCE(d3_3, 0) + 
    COALESCE(d3_4, 0) 
  ) STORED,
ADD COLUMN getting_along_people_domain_score smallint
  GENERATED ALWAYS AS (
    COALESCE(d4_1, 0) + 
    COALESCE(d4_2, 0) + 
    COALESCE(d4_3, 0) + 
    COALESCE(d4_4, 0) + 
    COALESCE(d4_5, 0)
  ) STORED,
ADD COLUMN household_activities_domain_score smallint
  GENERATED ALWAYS AS (
    COALESCE(d5_1, 0) + 
    COALESCE(d5_2, 0) + 
    COALESCE(d5_3, 0) + 
    COALESCE(d5_4, 0)
    ) STORED,
ADD COLUMN school_work_activites_domain_score smallint
  GENERATED ALWAYS AS (
    COALESCE(d5_5,0) +
    COALESCE(d5_6, 0) + 
    COALESCE(d5_7, 0) + 
    COALESCE(d5_8,0)
    ) STORED,
ADD COLUMN participation_domain_score smallint
  GENERATED ALWAYS AS (
    COALESCE(d6_1, 0) + 
    COALESCE(d6_2, 0) + 
    COALESCE(d6_3, 0) + 
    COALESCE(d6_4, 0) + 
    COALESCE(d6_5,0) +
    COALESCE(d6_6, 0) + 
    COALESCE(d6_7, 0) + 
    COALESCE(d6_8,0)
  ) STORED;
  */
/*
  ALTER TABLE whodas_responses
ADD COLUMN total_simple_score smallint
  GENERATED ALWAYS AS (
    -- Domain 1: Cognition
    COALESCE(d1_1,0) + COALESCE(d1_2,0) + COALESCE(d1_3,0) + COALESCE(d1_4,0) + COALESCE(d1_5,0) + COALESCE(d1_6,0) +
    -- Domain 2: Mobility
    COALESCE(d2_1,0) + COALESCE(d2_2,0) + COALESCE(d2_3,0) + COALESCE(d2_4,0) + COALESCE(d2_5,0) +
    -- Domain 3: Self-care
    COALESCE(d3_1,0) + COALESCE(d3_2,0) + COALESCE(d3_3,0) + COALESCE(d3_4,0) +
    -- Domain 4: Getting along
    COALESCE(d4_1,0) + COALESCE(d4_2,0) + COALESCE(d4_3,0) + COALESCE(d4_4,0) + COALESCE(d4_5,0) +
    -- Domain 5: Life Activities (Household + School/Work)
    COALESCE(d5_1,0) + COALESCE(d5_2,0) + COALESCE(d5_3,0) + COALESCE(d5_4,0) +
    COALESCE(d5_5,0) + COALESCE(d5_6,0) + COALESCE(d5_7,0) + COALESCE(d5_8,0) +
    -- Domain 6: Participation
    COALESCE(d6_1,0) + COALESCE(d6_2,0) + COALESCE(d6_3,0) + COALESCE(d6_4,0) + 
    COALESCE(d6_5,0) + COALESCE(d6_6,0) + COALESCE(d6_7,0) + COALESCE(d6_8,0)
  ) STORED,
ADD COLUMN whodas_percent_score float
  GENERATED ALWAYS AS (
    (
      (COALESCE(d1_1,0) + COALESCE(d1_2,0) + COALESCE(d1_3,0) + COALESCE(d1_4,0) + COALESCE(d1_5,0) + COALESCE(d1_6,0) +
       COALESCE(d2_1,0) + COALESCE(d2_2,0) + COALESCE(d2_3,0) + COALESCE(d2_4,0) + COALESCE(d2_5,0) +
       COALESCE(d3_1,0) + COALESCE(d3_2,0) + COALESCE(d3_3,0) + COALESCE(d3_4,0) +
       COALESCE(d4_1,0) + COALESCE(d4_2,0) + COALESCE(d4_3,0) + COALESCE(d4_4,0) + COALESCE(d4_5,0) +
       COALESCE(d5_1,0) + COALESCE(d5_2,0) + COALESCE(d5_3,0) + COALESCE(d5_4,0) +
       COALESCE(d5_5,0) + COALESCE(d5_6,0) + COALESCE(d5_7,0) + COALESCE(d5_8,0) +
       COALESCE(d6_1,0) + COALESCE(d6_2,0) + COALESCE(d6_3,0) + COALESCE(d6_4,0) + 
       COALESCE(d6_5,0) + COALESCE(d6_6,0) + COALESCE(d6_7,0) + COALESCE(d6_8,0)) 
    / 144.0) * 100
  ) STORED;
*/
/*
ALTER TABLE whodas_responses
ADD COLUMN IF NOT EXISTS whodas_complex_score float
*/
/*
ALTER TABLE whodas_responses
ADD COLUMN d5_9 smallint,
ADD COLUMN d5_10 smallint,
ADD COLUMN d5_01 smallint,
ADD COLUMN d5_02 smallint;
*/
/*
ALTER TABLE whodas_responses
DROP COLUMN d5_9,
DROP COLUMN d5_10,
DROP COLUMN d5_01,
DROP COLUMN d5_02;
*/
/*
ALTER TABLE whodas_responses
ADD COLUMN do1_score float,
ADD COLUMN do2_score float,
ADD COLUMN do3_score float,
ADD COLUMN do4_score float,
ADD COLUMN do5_score float,
ADD COLUMN do6_score float;

ALTER TABLE whodas_responses
ADD COLUMN do5_house_score float,
ADD COLUMN do5_work_score float;

ALTER TABLE whodas_responses
DROP COLUMN do5_score;

-- 1. Ensure columns exist to hold the link back to the device
ALTER TABLE whodas_responses 
ADD COLUMN IF NOT EXISTS device_id text;

ALTER TABLE gcplar_responses 
ADD COLUMN IF NOT EXISTS device_id text;

-- 2. Add the Cascade constraints
-- This tells Postgres: "If a device_id is deleted from device_register, 
-- delete all rows here that match that device_id."

ALTER TABLE whodas_responses
DROP CONSTRAINT IF EXISTS fk_whodas_device,
ADD CONSTRAINT fk_whodas_device
FOREIGN KEY (device_id) 
REFERENCES device_registry(device_id) 
ON DELETE CASCADE;

ALTER TABLE gcplar_responses
DROP CONSTRAINT IF EXISTS fk_gcplar_device,
ADD CONSTRAINT fk_gcplar_device
FOREIGN KEY (device_id) 
REFERENCES device_registry(device_id) 
ON DELETE CASCADE;
*/
ALTER TABLE whodas_responses
DROP COLUMN do5_house_score,
DROP COLUMN do5_work_score,
ADD COLUMN do5_score float;