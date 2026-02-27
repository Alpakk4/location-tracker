set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.whodas_calculate_complex_score()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$DECLARE
    -- Recoded variables
    r11 int; r12 int; r13 int; r14 int; r15 int; r16 int;
    r21 int; r22 int; r23 int; r24 int; r25 int;
    r31 int; r32 int; r33 int; r34 int;
    r41 int; r42 int; r43 int; r44 int; r45 int;
    r52 int; r53 int; r54 int; r55 int; 
    r58 int; r59 int; r510 int; r511 int;
    r61 int; r62 int; r63 int; r64 int; r65 int; r66 int; r67 int; r68 int;
    
    v_sum_32 numeric;
    v_sum_work numeric;
BEGIN
    -- 1. RECODING LOGIC
    r11 := COALESCE(NEW.d1_1, 0); r12 := COALESCE(NEW.d1_2, 0); 
    r13 := COALESCE(NEW.d1_3, 0); r14 := COALESCE(NEW.d1_4, 0);
    r15 := CASE WHEN NEW.d1_5 IN (1,2) THEN 1 WHEN NEW.d1_5 IN (3,4) THEN 2 ELSE 0 END;
    r16 := CASE WHEN NEW.d1_6 IN (1,2) THEN 1 WHEN NEW.d1_6 IN (3,4) THEN 2 ELSE 0 END;

    r21 := COALESCE(NEW.d2_1, 0); r24 := COALESCE(NEW.d2_4, 0); r25 := COALESCE(NEW.d2_5, 0);
    r22 := CASE WHEN NEW.d2_2 IN (1,2) THEN 1 WHEN NEW.d2_2 IN (3,4) THEN 2 ELSE 0 END;
    r23 := CASE WHEN NEW.d2_3 IN (1,2) THEN 1 WHEN NEW.d2_3 IN (3,4) THEN 2 ELSE 0 END;

    r32 := COALESCE(NEW.d3_2, 0);
    r31 := CASE WHEN NEW.d3_1 IN (1,2) THEN 1 WHEN NEW.d3_1 IN (3,4) THEN 2 ELSE 0 END;
    r33 := CASE WHEN NEW.d3_3 IN (1,2) THEN 1 WHEN NEW.d3_3 IN (3,4) THEN 2 ELSE 0 END;
    r34 := CASE WHEN NEW.d3_4 IN (1,2) THEN 1 WHEN NEW.d3_4 IN (3,4) THEN 2 ELSE 0 END;

    r44 := COALESCE(NEW.d4_4, 0);
    r41 := CASE WHEN NEW.d4_1 IN (1,2) THEN 1 WHEN NEW.d4_1 IN (3,4) THEN 2 ELSE 0 END;
    r42 := CASE WHEN NEW.d4_2 IN (1,2) THEN 1 WHEN NEW.d4_2 IN (3,4) THEN 2 ELSE 0 END;
    r43 := CASE WHEN NEW.d4_3 IN (1,2) THEN 1 WHEN NEW.d4_3 IN (3,4) THEN 2 ELSE 0 END;
    r45 := CASE WHEN NEW.d4_5 IN (1,2) THEN 1 WHEN NEW.d4_5 IN (3,4) THEN 2 ELSE 0 END;

    r54 := COALESCE(NEW.d5_4, 0);
    r52 := CASE WHEN NEW.d5_2 IN (1,2) THEN 1 WHEN NEW.d5_2 IN (3,4) THEN 2 ELSE 0 END;
    r53 := CASE WHEN NEW.d5_3 IN (1,2) THEN 1 WHEN NEW.d5_3 IN (3,4) THEN 2 ELSE 0 END;
    r55 := CASE WHEN NEW.d5_5 IN (1,2) THEN 1 WHEN NEW.d5_5 IN (3,4) THEN 2 ELSE 0 END;

    r62 := COALESCE(NEW.d6_2, 0); r64 := COALESCE(NEW.d6_4, 0); 
    r65 := COALESCE(NEW.d6_5, 0); r67 := COALESCE(NEW.d6_7, 0);
    r61 := CASE WHEN NEW.d6_1 IN (1,2) THEN 1 WHEN NEW.d6_1 IN (3,4) THEN 2 ELSE 0 END;
    r63 := CASE WHEN NEW.d6_3 IN (1,2) THEN 1 WHEN NEW.d6_3 IN (3,4) THEN 2 ELSE 0 END;
    r66 := CASE WHEN NEW.d6_6 IN (1,2) THEN 1 WHEN NEW.d6_6 IN (3,4) THEN 2 ELSE 0 END;
    r68 := CASE WHEN NEW.d6_8 IN (1,2) THEN 1 WHEN NEW.d6_8 IN (3,4) THEN 2 ELSE 0 END;

    r58 := CASE WHEN NEW.d5_8 IN (1,2) THEN 1 WHEN NEW.d5_8 IN (3,4) THEN 2 ELSE 0 END;
    r59 := COALESCE(NEW.d5_9, 0); 
    r510 := COALESCE(NEW.d5_10, 0); 
    r511 := COALESCE(NEW.d5_11, 0);

    -- 2. CALCULATE SUMS
    v_sum_32 := (r11+r12+r13+r14+r15+r16+r21+r22+r23+r24+r25+r31+r32+r33+r34+r41+r42+r43+r44+r45+r52+r53+r54+r55+r61+r62+r63+r64+r65+r66+r67+r68);
    v_sum_work := (r58 + r59 + r510 + r511);

    -- 3. FINAL CALCULATIONS
    IF NEW.d5_8 IS NOT NULL THEN
        NEW.whodas_complex_score := (v_sum_32 + v_sum_work) * 100.0 / 106.0;
        NEW.st_s36 := (v_sum_32 + v_sum_work) * 100.0 / 106.0;
        NEW.st_s32 := v_sum_32 * 100.0 / 92.0;
    ELSE
        NEW.whodas_complex_score := v_sum_32 * 100.0 / 92.0;
        NEW.st_s32 := v_sum_32 * 100.0 / 92.0;
        NEW.st_s36 := NULL;
    END IF;

    NEW.do1 := (r11 + r12 + r13 + r14 + r15 + r16) * 100.0 / 20.0;

    RETURN NEW;
END;$function$
;

CREATE TRIGGER whodas_populate_complex_score BEFORE INSERT OR UPDATE ON public.whodas_responses FOR EACH ROW EXECUTE FUNCTION public.whodas_calculate_complex_score();


