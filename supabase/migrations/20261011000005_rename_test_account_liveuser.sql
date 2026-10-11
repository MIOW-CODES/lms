-- Rename the multi-role test/staff account display name (user request
-- 2026-10-11): sidebar shows "Test Account · Teacher"; make it read
-- "LiveUser" so it's clearly the shared live-testing account, not a fixture.
--
-- Login (email test@g.msuiit.edu.ph, PIN 0916) and the role-view switcher are
-- unchanged. Idempotent: touches only this single row.

UPDATE public.profiles
   SET full_name = 'LiveUser'
 WHERE lower(coalesce(email, '')) = 'test@g.msuiit.edu.ph'
   AND deleted_at IS NULL;

DO $$
DECLARE
  renamed int;
BEGIN
  GET DIAGNOSTICS renamed = ROW_COUNT;
  RAISE NOTICE 'liveuser rename: % row(s) updated', renamed;
END $$;
