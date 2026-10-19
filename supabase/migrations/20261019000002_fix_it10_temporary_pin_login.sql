-- Use the application's supported temporary-credential onboarding path for
-- IT10 students. On successful login verifyPin() compares this temporary
-- plaintext value, replaces it with a bcryptjs hash, and clears `pin`.
--
-- This supersedes 20261019000001, whose pgcrypto-generated bcrypt hashes did
-- not authenticate through the deployed JavaScript runtime.

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
SET pin = '1234',
    pin_hash = NULL,
    pin_must_change = true,
    failed_login_attempts = 0,
    locked_until = NULL
FROM it10_students
WHERE p.id = it10_students.id;

-- Clear all shared limiter buckets that verifyPinLogin() can create for these
-- profiles. The limiter hashes raw keys with SHA-256 before storing them.
WITH it10_students AS (
  SELECT DISTINCT p.id, p.student_id, p.email, p.username, p.employee_id
  FROM public.profiles AS p
  JOIN public.enrollments AS e ON e.student_id = p.id
  JOIN public.courses AS c ON c.id = e.course_id
  WHERE p.role = 'student'
    AND p.deleted_at IS NULL
    AND upper(btrim(c.code)) = 'IT10'
), raw_keys AS (
  SELECT 'pin:' || id::text AS value FROM it10_students
  UNION ALL SELECT 'login:profile:' || id::text FROM it10_students
  UNION ALL SELECT 'secret:' || id::text FROM it10_students
  UNION ALL SELECT 'login:ident:' || lower(student_id) FROM it10_students WHERE student_id IS NOT NULL
  UNION ALL SELECT 'login:ident:' || lower(email) FROM it10_students WHERE email IS NOT NULL
  UNION ALL SELECT 'login:ident:' || lower(username) FROM it10_students WHERE username IS NOT NULL
  UNION ALL SELECT 'login:ident:' || lower(employee_id) FROM it10_students WHERE employee_id IS NOT NULL
), bucket_keys AS (
  SELECT encode(extensions.digest(value, 'sha256'), 'hex') AS value
  FROM raw_keys
)
DELETE FROM public.auth_rate_limits AS limits
USING bucket_keys
WHERE limits.bucket_key = bucket_keys.value;

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
    AND p.pin = '1234'
    AND p.pin_hash IS NULL
    AND p.pin_must_change = true
    AND coalesce(p.failed_login_attempts, 0) = 0
    AND p.locked_until IS NULL;

  IF enrolled_count = 0 OR valid_count <> enrolled_count THEN
    RAISE EXCEPTION
      'IT10 temporary credential verification failed: % of % accounts valid',
      valid_count,
      enrolled_count;
  END IF;

  RAISE NOTICE
    'IT10 temporary credential login fixed for % active enrolled students',
    valid_count;
END $$;
