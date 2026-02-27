drop trigger if exists "auto_generate_questionnaires" on "public"."device_registry";

alter table "public"."gcplar_responses" drop constraint "gcplar_responses_score_total_check";

alter table "public"."gcplar_responses" drop column "score_total";

alter table "public"."gcplar_responses" add column "device_id" text;

alter table "public"."whodas_responses" drop column "d5_01";

alter table "public"."whodas_responses" drop column "d5_02";

alter table "public"."whodas_responses" drop column "d5_10";

alter table "public"."whodas_responses" drop column "d5_9";

alter table "public"."whodas_responses" add column "device_id" text;

alter table "public"."whodas_responses" add column "do1_score" double precision;

alter table "public"."whodas_responses" add column "do2_score" double precision;

alter table "public"."whodas_responses" add column "do3_score" double precision;

alter table "public"."whodas_responses" add column "do4_score" double precision;

alter table "public"."whodas_responses" add column "do5_score" double precision;

alter table "public"."whodas_responses" add column "do6_score" double precision;

alter table "public"."gcplar_responses" add constraint "fk_gcplar_device" FOREIGN KEY (device_id) REFERENCES public.device_registry(device_id) ON DELETE CASCADE not valid;

alter table "public"."gcplar_responses" validate constraint "fk_gcplar_device";

alter table "public"."whodas_responses" add constraint "fk_whodas_device" FOREIGN KEY (device_id) REFERENCES public.device_registry(device_id) ON DELETE CASCADE not valid;

alter table "public"."whodas_responses" validate constraint "fk_whodas_device";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.initialize_new_device()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$DECLARE
    v_whodas_id UUID;
    v_gcplar_id UUID;
BEGIN
    -- 1. Create the WHODAS row (Device now exists, so FK will pass)
    INSERT INTO whodas_responses (device_id) 
    VALUES (NEW.device_id) 
    RETURNING id INTO v_whodas_id;

    -- 2. Create the GCPLAR row
    INSERT INTO gcplar_responses (device_id) 
    VALUES (NEW.device_id) 
    RETURNING id INTO v_gcplar_id;

    -- 3. Update the device record with the new response IDs
    UPDATE device_registry
    SET whodas_id = v_whodas_id, 
        gcplar_id = v_gcplar_id
    WHERE device_id = NEW.device_id;

    RETURN NULL; -- In AFTER triggers, return value is ignored
END;$function$
;

CREATE OR REPLACE FUNCTION public.whodas_calculate_complex_score()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$-- WHODAS 2.0 Complex Scoring Trigger Function
--
-- Overall score logic:
--   If respondent works (d5_5 is not null): score = (v_sum_32 + v_sum_work) * 100 / 106
--   Otherwise:                              score = v_sum_32 * 100 / 92
--
-- Domain max scores (denominators):
--   D1: 20  D2: 16  D3: 10  D4: 12  D5 household: 10  D5 work: 14  D6: 24
-- WHODAS 2.0 Complex Scoring Trigger Function (Revised)
DECLARE
    -- Recoded variables (Pattern A: 0-4, Pattern B: 0-2)
    r11 int; r12 int; r13 int; r14 int; r15 int; r16 int;
    r21 int; r22 int; r23 int; r24 int; r25 int;
    r31 int; r32 int; r33 int; r34 int;
    r41 int; r42 int; r43 int; r44 int; r45 int;
    r51 int; r52 int; r53 int; r54 int;   -- Household
    r55 int; r56 int; r57 int; r58 int;   -- Work/School
    r61 int; r62 int; r63 int; r64 int; r65 int; r66 int; r67 int; r68 int;
    
    -- Intermediate Sums
    v_sum_d1 int; v_sum_d2 int; v_sum_d3 int; v_sum_d4 int;
    v_sum_d5a int; v_sum_d5b int; v_sum_d6 int;
    v_total_points int;
BEGIN
    -- 1. RECODE LOGIC 
    -- D1: Cognition (Max 20)
    r11 := COALESCE(NEW.d1_1, 0); r12 := COALESCE(NEW.d1_2, 0); 
    r13 := COALESCE(NEW.d1_3, 0); r14 := COALESCE(NEW.d1_4, 0);
    r15 := CASE WHEN NEW.d1_5 IN (1,2) THEN 1 WHEN NEW.d1_5 IN (3,4) THEN 2 ELSE 0 END;
    r16 := CASE WHEN NEW.d1_6 IN (1,2) THEN 1 WHEN NEW.d1_6 IN (3,4) THEN 2 ELSE 0 END;
    v_sum_d1 := r11 + r12 + r13 + r14 + r15 + r16;

    -- D2: Mobility (Max 16)
    r21 := COALESCE(NEW.d2_1, 0); r24 := COALESCE(NEW.d2_4, 0); r25 := COALESCE(NEW.d2_5, 0);
    r22 := CASE WHEN NEW.d2_2 IN (1,2) THEN 1 WHEN NEW.d2_2 IN (3,4) THEN 2 ELSE 0 END;
    r23 := CASE WHEN NEW.d2_3 IN (1,2) THEN 1 WHEN NEW.d2_3 IN (3,4) THEN 2 ELSE 0 END;
    v_sum_d2 := r21 + r22 + r23 + r24 + r25;

    -- D3: Self-care (Max 10)
    r32 := COALESCE(NEW.d3_2, 0);
    r31 := CASE WHEN NEW.d3_1 IN (1,2) THEN 1 WHEN NEW.d3_1 IN (3,4) THEN 2 ELSE 0 END;
    r33 := CASE WHEN NEW.d3_3 IN (1,2) THEN 1 WHEN NEW.d3_3 IN (3,4) THEN 2 ELSE 0 END;
    r34 := CASE WHEN NEW.d3_4 IN (1,2) THEN 1 WHEN NEW.d3_4 IN (3,4) THEN 2 ELSE 0 END;
    v_sum_d3 := r31 + r32 + r33 + r34;

    -- D4: Getting Along (Max 12)
    r44 := COALESCE(NEW.d4_4, 0);
    r41 := CASE WHEN NEW.d4_1 IN (1,2) THEN 1 WHEN NEW.d4_1 IN (3,4) THEN 2 ELSE 0 END;
    r42 := CASE WHEN NEW.d4_2 IN (1,2) THEN 1 WHEN NEW.d4_2 IN (3,4) THEN 2 ELSE 0 END;
    r43 := CASE WHEN NEW.d4_3 IN (1,2) THEN 1 WHEN NEW.d4_3 IN (3,4) THEN 2 ELSE 0 END;
    r45 := CASE WHEN NEW.d4_5 IN (1,2) THEN 1 WHEN NEW.d4_5 IN (3,4) THEN 2 ELSE 0 END;
    v_sum_d4 := r41 + r42 + r43 + r44 + r45;

    -- D5a: Life Activities - Household (Max 10)
    r51 := CASE WHEN NEW.d5_1 IN (1,2) THEN 1 WHEN NEW.d5_1 IN (3,4) THEN 2 ELSE 0 END;
    r52 := CASE WHEN NEW.d5_2 IN (1,2) THEN 1 WHEN NEW.d5_2 IN (3,4) THEN 2 ELSE 0 END;
    r53 := CASE WHEN NEW.d5_3 IN (1,2) THEN 1 WHEN NEW.d5_3 IN (3,4) THEN 2 ELSE 0 END;
    r54 := COALESCE(NEW.d5_4, 0);
    v_sum_d5a := r51 + r52 + r53 + r54;

    -- D5b: Life Activities - Work/School (Max 14)
    r55 := CASE WHEN NEW.d5_5 IN (1,2) THEN 1 WHEN NEW.d5_5 IN (3,4) THEN 2 ELSE 0 END;
    r56 := COALESCE(NEW.d5_6, 0); r57 := COALESCE(NEW.d5_7, 0); r58 := COALESCE(NEW.d5_8, 0);
    v_sum_d5b := r55 + r56 + r57 + r58;

    -- D6: Participation (Max 24)
    r62 := COALESCE(NEW.d6_2, 0); r64 := COALESCE(NEW.d6_4, 0); r65 := COALESCE(NEW.d6_5, 0); r67 := COALESCE(NEW.d6_7, 0);
    r61 := CASE WHEN NEW.d6_1 IN (1,2) THEN 1 WHEN NEW.d6_1 IN (3,4) THEN 2 ELSE 0 END;
    r63 := CASE WHEN NEW.d6_3 IN (1,2) THEN 1 WHEN NEW.d6_3 IN (3,4) THEN 2 ELSE 0 END;
    r66 := CASE WHEN NEW.d6_6 IN (1,2) THEN 1 WHEN NEW.d6_6 IN (3,4) THEN 2 ELSE 0 END;
    r68 := CASE WHEN NEW.d6_8 IN (1,2) THEN 1 WHEN NEW.d6_8 IN (3,4) THEN 2 ELSE 0 END;
    v_sum_d6 := r61 + r62 + r63 + r64 + r65 + r66 + r67 + r68;

    -- 2. CALCULATE INDIVIDUAL DOMAIN PERCENTAGES
    NEW.do1_score := v_sum_d1 * 100.0 / 20.0;
    NEW.do2_score := v_sum_d2 * 100.0 / 16.0;
    NEW.do3_score := v_sum_d3 * 100.0 / 10.0;
    NEW.do4_score := v_sum_d4 * 100.0 / 12.0;
    NEW.do6_score := v_sum_d6 * 100.0 / 24.0;

    -- 3. DOMAIN 5 & GLOBAL COMPLEX SCORE LOGIC
    IF NEW.d5_5 IS NOT NULL THEN
        -- With Work/School
        NEW.do5_score := (v_sum_d5a + v_sum_d5b) * 100.0 / 24.0;
        
        v_total_points := v_sum_d1 + v_sum_d2 + v_sum_d3 + v_sum_d4 + v_sum_d5a + v_sum_d5b + v_sum_d6;
        NEW.whodas_complex_score := v_total_points * 100.0 / 106.0;
    ELSE
        -- Without Work/School
        NEW.do5_score := v_sum_d5a * 100.0 / 10.0;
        
        v_total_points := v_sum_d1 + v_sum_d2 + v_sum_d3 + v_sum_d4 + v_sum_d5a + v_sum_d6;
        NEW.whodas_complex_score := v_total_points * 100.0 / 92.0;
    END IF;

    RETURN NEW;
END;$function$
;

CREATE TRIGGER trigger_init_device AFTER INSERT ON public.device_registry FOR EACH ROW EXECUTE FUNCTION public.initialize_new_device();


