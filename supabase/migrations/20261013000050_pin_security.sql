-- PIN security policy (user request 2026-10-13).
--
-- 1) Rotate the two documented default admin PINs. The old defaults ('1234'
--    and '3333') are public knowledge and let anyone sign in as an admin. The
--    replacement bcrypt hashes below are pre-generated and written VERBATIM —
--    they are never re-hashed or altered here. The legacy plaintext `pin`
--    column is cleared at the same time so the old defaults stop authenticating
--    through the legacy fallback in the sign-in path.
-- 2) Add profiles.pin_must_change — the forced-PIN-change gate flag.
-- 3) Flag every student-role profile: student PINs are currently the student
--    ID, which classmates can use to sign in as each other during graded work,
--    so students must pick a private PIN at next login. Teachers/admins are
--    not flagged.
--
-- Accounts are never deleted or otherwise restructured. Idempotent: every
-- statement is safe to re-run; effects are counted via RAISE NOTICE.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS pin_must_change boolean NOT NULL DEFAULT false;

-- ── 1) Rotate default admin PINs (pre-generated bcrypt hashes, verbatim) ──

UPDATE public.profiles
   SET pin_hash = '$2b$10$oCcxJhIQMNg/YJaAdnAxR.ra3GebhuMltEpI35INs1KwEOlNjGIx2',
       pin = NULL,
       pin_must_change = false,
       failed_login_attempts = 0,
       locked_until = NULL
 WHERE lower(coalesce(email, '')) = 'josephalan.vergara@g.msuiit.edu.ph'
   AND deleted_at IS NULL;

DO $$
DECLARE
  rotated_count int;
BEGIN
  GET DIAGNOSTICS rotated_count = ROW_COUNT;
  RAISE NOTICE 'pin_security: josephalan.vergara@g.msuiit.edu.ph admin PIN rotated — % row(s)', rotated_count;
END $$;

UPDATE public.profiles
   SET pin_hash = '$2b$10$oCcxJhIQMNg/YJaAdnAxR.KN.Iq3UDus0AnAQbJJkI1TzP7cbjwga',
       pin = NULL,
       pin_must_change = false,
       failed_login_attempts = 0,
       locked_until = NULL
 WHERE lower(coalesce(email, '')) = 'alan.vergara@g.msuiit.edu.ph'
   AND deleted_at IS NULL;

DO $$
DECLARE
  rotated_count int;
BEGIN
  GET DIAGNOSTICS rotated_count = ROW_COUNT;
  RAISE NOTICE 'pin_security: alan.vergara@g.msuiit.edu.ph admin PIN rotated — % row(s)', rotated_count;
END $$;

-- ── 2/3) Force students to choose a private PIN at next login ──

UPDATE public.profiles
   SET pin_must_change = true
 WHERE role = 'student'
   AND deleted_at IS NULL;

DO $$
DECLARE
  flagged_count int;
BEGIN
  GET DIAGNOSTICS flagged_count = ROW_COUNT;
  RAISE NOTICE 'pin_security: pin_must_change set for % student profile(s)', flagged_count;
END $$;
