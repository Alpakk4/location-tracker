-- Phase 2: RLS lockdown and grants cleanup
--
-- All data access now goes through edge functions using service_role,
-- which bypasses RLS and retains full table privileges.  Direct
-- PostgREST access via the publishable anon key is blocked.

-- ============================================================
-- 1. Data tables – drop permissive policies, revoke all grants
-- ============================================================

-- locationsvisitednew
DROP POLICY IF EXISTS "Allow anonymous inserts" ON public.locationsvisitednew;
REVOKE ALL ON public.locationsvisitednew FROM anon, authenticated;

-- diaries
DROP POLICY IF EXISTS "Allow anonymous inserts"  ON public.diaries;
DROP POLICY IF EXISTS "Allow anonymous selects"  ON public.diaries;
DROP POLICY IF EXISTS "Allow anonymous updates"  ON public.diaries;
REVOKE ALL ON public.diaries FROM anon, authenticated;

-- diary_visits
DROP POLICY IF EXISTS "Allow anonymous inserts"  ON public.diary_visits;
DROP POLICY IF EXISTS "Allow anonymous selects"  ON public.diary_visits;
DROP POLICY IF EXISTS "Allow anonymous updates"  ON public.diary_visits;
REVOKE ALL ON public.diary_visits FROM anon, authenticated;

-- diary_journeys
DROP POLICY IF EXISTS "Allow anonymous inserts"  ON public.diary_journeys;
DROP POLICY IF EXISTS "Allow anonymous selects"  ON public.diary_journeys;
DROP POLICY IF EXISTS "Allow anonymous updates"  ON public.diary_journeys;
REVOKE ALL ON public.diary_journeys FROM anon, authenticated;

-- diary_visit_entries
DROP POLICY IF EXISTS "Allow anonymous inserts"  ON public.diary_visit_entries;
DROP POLICY IF EXISTS "Allow anonymous selects"  ON public.diary_visit_entries;
REVOKE ALL ON public.diary_visit_entries FROM anon, authenticated;

-- diary_journey_entries
DROP POLICY IF EXISTS "Allow anonymous inserts"  ON public.diary_journey_entries;
DROP POLICY IF EXISTS "Allow anonymous selects"  ON public.diary_journey_entries;
REVOKE ALL ON public.diary_journey_entries FROM anon, authenticated;

-- places
DROP POLICY IF EXISTS "Write to place table" ON public.places;
REVOKE ALL ON public.places FROM anon, authenticated;

-- ============================================================
-- 2. device_registry – tighten grants, keep SELECT/INSERT for
--    potential direct onboarding via PostgREST
-- ============================================================

REVOKE DELETE, TRUNCATE ON public.device_registry FROM anon, authenticated;

-- ============================================================
-- 3. Questionnaire tables – remove destructive grants
-- ============================================================

REVOKE DELETE, TRUNCATE ON public.gcplar_responses  FROM anon, authenticated;
REVOKE DELETE, TRUNCATE ON public.whodas_responses   FROM anon, authenticated;

-- ============================================================
-- 4. clear_diary_data → SECURITY DEFINER
--
--    The function DELETEs from diary_visit_entries,
--    diary_journey_entries, diary_visits, and diary_journeys.
--    Under SECURITY INVOKER those DELETEs are blocked now that
--    anon/authenticated have no table privileges.  SECURITY
--    DEFINER lets it run as the function owner (postgres),
--    bypassing RLS/grants.  Safe because it is only reachable
--    via edge functions using the service_role key.
-- ============================================================

ALTER FUNCTION public.clear_diary_data(uuid) SECURITY DEFINER;

-- Prevent anon/authenticated from invoking these RPC functions
-- directly via PostgREST.  Edge functions use service_role,
-- which retains EXECUTE.
REVOKE EXECUTE ON FUNCTION public.clear_diary_data(uuid)       FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.submit_diary(text, text, jsonb, jsonb) FROM anon, authenticated;
