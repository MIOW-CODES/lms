-- Student PIN convention (user request 2026-10-11): every student's PIN is
-- their own ID number, matching the college convention documented in README
-- ("College default PIN is your Student ID number") and now applied as the
-- standard for ALL students (Grade 7–10 included, which previously defaulted
-- to '1234').
--
-- Uses the legacy plaintext credential path ('pin' column, pin_hash = NULL):
-- the app's sign-in re-hashes each PIN to bcrypt on that student's first
-- successful login — same mechanism as 20261011000001/00003.
--
-- Scope: role = 'student' only, deleted_at IS NULL. Staff/admin accounts and
-- the LiveUser test account are untouched. Students who changed their PIN get
-- reset to the convention intentionally (explicit user request).
--
-- Idempotent: re-running sets the same value; the UPDATE only rewrites rows
-- whose pin column already differs from their student_id.

UPDATE public.profiles
   SET pin = student_id,
       pin_hash = NULL,
       failed_login_attempts = 0,
       locked_until = NULL
 WHERE role = 'student'
   AND deleted_at IS NULL
   AND student_id IS NOT NULL
   AND student_id <> ''
   AND coalesce(pin, '') IS DISTINCT FROM student_id;

DO $$
DECLARE
  reset_students int;
  mismatched int;
BEGIN
  GET DIAGNOSTICS reset_students = ROW_COUNT;
  SELECT count(*) INTO mismatched
    FROM public.profiles
   WHERE role = 'student' AND deleted_at IS NULL
     AND student_id IS NOT NULL AND student_id <> ''
     AND coalesce(pin, '') IS DISTINCT FROM student_id;
  RAISE NOTICE 'student PIN = student_id: % row(s) reset, % still mismatched', reset_students, mismatched;
END $$;
