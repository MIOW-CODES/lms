-- Restore a known temporary credential for every active student enrolled in
-- IT10. This is intentionally scoped through enrollments/course code so no
-- staff, administrators, or students outside IT10 are modified.
--
-- The temporary PIN is bcrypt-hashed immediately; plaintext is never stored.
-- Students must replace it after their first successful login.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

WITH it10_students AS (
  SELECT DISTINCT p.id
  FROM public.profiles AS p
  JOIN public.enrollments AS e ON e.student_id = p.id
  JOIN public.courses AS c ON c.id = e.course_id
  WHERE p.role = 'student'
    AND p.deleted_at IS NULL
    AND upper(btrim(c.code)) = 'IT10'
)
UPDATE public.profiles AS p
SET pin = NULL,
    pin_hash = extensions.crypt('1234', extensions.gen_salt('bf', 12)),
    pin_must_change = true,
    failed_login_attempts = 0,
    locked_until = NULL
FROM it10_students
WHERE p.id = it10_students.id;

DO $$
DECLARE
  enrolled_count integer;
  valid_count integer;
BEGIN
  SELECT count(DISTINCT p.id)
  INTO enrolled_count
  FROM public.profiles AS p
  JOIN public.enrollments AS e ON e.student_id = p.id
  JOIN public.courses AS c ON c.id = e.course_id
  WHERE p.role = 'student'
    AND p.deleted_at IS NULL
    AND upper(btrim(c.code)) = 'IT10';

  SELECT count(DISTINCT p.id)
  INTO valid_count
  FROM public.profiles AS p
  JOIN public.enrollments AS e ON e.student_id = p.id
  JOIN public.courses AS c ON c.id = e.course_id
  WHERE p.role = 'student'
    AND p.deleted_at IS NULL
    AND upper(btrim(c.code)) = 'IT10'
    AND p.pin IS NULL
    AND p.pin_hash IS NOT NULL
    AND extensions.crypt('1234', p.pin_hash) = p.pin_hash
    AND p.pin_must_change = true
    AND coalesce(p.failed_login_attempts, 0) = 0
    AND p.locked_until IS NULL;

  IF enrolled_count = 0 THEN
    RAISE EXCEPTION 'IT10 credential reset found no active enrolled students';
  END IF;

  IF valid_count <> enrolled_count THEN
    RAISE EXCEPTION
      'IT10 credential reset verification failed: % of % accounts valid',
      valid_count,
      enrolled_count;
  END IF;

  RAISE NOTICE
    'IT10 credential reset complete: % active enrolled students use temporary PIN 1234',
    valid_count;
END $$;
