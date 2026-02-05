alter table "public"."locationsvisitednew" add column "Motion Type" jsonb default '{"motion": "unknown", "confidence": "unknown"}'::jsonb;



