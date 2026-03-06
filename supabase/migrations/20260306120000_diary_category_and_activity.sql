-- Add place_category and confirmed_category to diary_visits.
-- activity_label already exists from the initial schema.
ALTER TABLE "public"."diary_visits" ADD COLUMN IF NOT EXISTS "place_category" text;
ALTER TABLE "public"."diary_visits" ADD COLUMN IF NOT EXISTS "confirmed_category" boolean;

-- Recreate submit_diary to include confirmed_category and place_category in the
-- visit update payload.
CREATE OR REPLACE FUNCTION submit_diary(
  p_device_id text,
  p_date text,
  p_visit_updates jsonb,
  p_journey_updates jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_diary_id uuid;
  v_updated_visits int := 0;
  v_updated_journeys int := 0;
  v_entry jsonb;
BEGIN
  -- Atomic check-and-claim
  UPDATE diaries
    SET submitted_at = now()
  WHERE deviceid = p_device_id
    AND diary_date = p_date::date
    AND submitted_at IS NULL
  RETURNING id INTO v_diary_id;

  IF v_diary_id IS NULL THEN
    RAISE EXCEPTION 'diary_not_available';
  END IF;

  -- Update visit rows
  FOR v_entry IN SELECT * FROM jsonb_array_elements(p_visit_updates)
  LOOP
    UPDATE diary_visits
      SET activity_label     = v_entry->>'activity_label',
          place_category     = v_entry->>'place_category',
          confirmed_place    = (v_entry->>'confirmed_place')::boolean,
          confirmed_activity = (v_entry->>'confirmed_activity')::boolean,
          confirmed_category = (v_entry->>'confirmed_category')::boolean,
          user_context       = v_entry->>'user_context'
    WHERE diary_id = v_diary_id
      AND visit_id = v_entry->>'source_entryid';
    v_updated_visits := v_updated_visits + 1;
  END LOOP;

  -- Update journey rows
  IF p_journey_updates IS NOT NULL AND jsonb_array_length(p_journey_updates) > 0 THEN
    FOR v_entry IN SELECT * FROM jsonb_array_elements(p_journey_updates)
    LOOP
      UPDATE diary_journeys
        SET confirmed_transport = (v_entry->>'confirmed_transport')::boolean,
            travel_reason       = v_entry->>'travel_reason'
      WHERE diary_id = v_diary_id
        AND journey_id = v_entry->>'source_journey_id';
      v_updated_journeys := v_updated_journeys + 1;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'updated_visits', v_updated_visits,
    'updated_journeys', v_updated_journeys
  );
END;
$$;
