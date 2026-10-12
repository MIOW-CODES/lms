-- MIOW-LMS: drop anon "Public demo access" RLS policies (security hardening)
-- Audit M3: several catalog/override tables shipped with an unrestricted
-- `FOR ALL TO anon, authenticated USING (true)` policy plus broad GRANTs, which
-- left them readable and writable by unauthenticated clients. These tables are
-- only accessed through the server (service_role / owner path), so the anon and
-- authenticated privileges are dropped entirely. RLS stays enabled (default
-- deny). Idempotent: policies are dropped IF EXISTS and grants revoked
-- defensively; a NOTICE is raised per table.

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'quiz_score_overrides',
    'tos',
    'course_meetings',
    'course_meeting_members',
    'course_sections',
    'subjects',
    'sections'
  ] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('DROP POLICY IF EXISTS "Public demo access" ON public.%I', t);
      -- `tos` shipped its unrestricted anon policy under a different name.
      EXECUTE format('DROP POLICY IF EXISTS "public full access tos" ON public.%I', t);
      EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
      RAISE NOTICE 'drop_anon_demo_policies: dropped demo policy and revoked anon/authenticated grants on public.%', t;
    ELSE
      RAISE NOTICE 'drop_anon_demo_policies: public.% does not exist — skipped', t;
    END IF;
  END LOOP;
END $$;
