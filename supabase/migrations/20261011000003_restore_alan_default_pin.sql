-- Password recovery for the Admin & Teacher account (user request 2026-10-11).
--
-- alan.vergara@g.msuiit.edu.ph is documented (README "Default Credentials":
-- Admin & Teacher = '3333'), but the stored credential is a bcrypt hash and
-- bcrypt is one-way — the existing PIN cannot be read back, only replaced.
--
-- Reset this single account to the documented default '3333' via the legacy
-- plaintext path: the app's sign-in re-hashes the plaintext PIN to bcrypt on
-- the first successful login (same mechanism as 20261011000001).
--
-- Idempotent: touches only this single row; no other account, table, grant or
-- RLS policy is modified.

UPDATE public.profiles
   SET pin = '3333',
       pin_hash = NULL,
       failed_login_attempts = 0,
       locked_until = NULL
 WHERE lower(coalesce(email, '')) = 'alan.vergara@g.msuiit.edu.ph'
   AND deleted_at IS NULL;

DO $$
DECLARE
  reset_count int;
BEGIN
  GET DIAGNOSTICS reset_count = ROW_COUNT;
  RAISE NOTICE 'alan.vergara PIN reset to documented default: % row(s)', reset_count;
END $$;
