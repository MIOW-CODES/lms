-- Targeted production repair for Samantha Jane Aruelo. Ensure the live profile
-- is attached to IT10, restore the documented temporary PIN, and clear both
-- row-level and shared login lockouts.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

DO $$
DECLARE
  student_uuid uuid;
  course_uuid uuid;
  matching_profiles integer;
BEGIN
  SELECT count(*)
  INTO matching_profiles
  FROM public.profiles
  WHERE student_id = '2026-0003'
    AND role = 'student'
    AND deleted_at IS NULL;

  IF matching_profiles <> 1 THEN
    RAISE EXCEPTION
      'Expected exactly one active student profile for 2026-0003; found %',
      matching_profiles;
  END IF;

  SELECT id
  INTO student_uuid
  FROM public.profiles
  WHERE student_id = '2026-0003'
    AND role = 'student'
    AND deleted_at IS NULL;

  SELECT id
  INTO course_uuid
  FROM public.courses
  WHERE upper(btrim(code)) = 'IT10'
  ORDER BY created_at ASC, id ASC
  LIMIT 1;

  IF course_uuid IS NULL THEN
    RAISE EXCEPTION 'Canonical IT10 course not found';
  END IF;

  INSERT INTO public.enrollments (student_id, course_id)
  VALUES (student_uuid, course_uuid)
  ON CONFLICT (student_id, course_id) DO NOTHING;

  UPDATE public.profiles
  SET pin = '1234',
      pin_hash = NULL,
      pin_must_change = true,
      failed_login_attempts = 0,
      locked_until = NULL
  WHERE id = student_uuid;

  DELETE FROM public.auth_rate_limits
  WHERE bucket_key IN (
    encode(extensions.digest('pin:' || student_uuid::text, 'sha256'), 'hex'),
    encode(extensions.digest('login:profile:' || student_uuid::text, 'sha256'), 'hex'),
    encode(extensions.digest('secret:' || student_uuid::text, 'sha256'), 'hex'),
    encode(extensions.digest('login:ident:2026-0003', 'sha256'), 'hex'),
    encode(extensions.digest('login:ident:samanthajane.aruelo@g.msuiit.edu.ph', 'sha256'), 'hex')
  );

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles AS p
    JOIN public.enrollments AS e ON e.student_id = p.id
    WHERE p.id = student_uuid
      AND e.course_id = course_uuid
      AND p.pin = '1234'
      AND p.pin_hash IS NULL
      AND p.pin_must_change = true
      AND coalesce(p.failed_login_attempts, 0) = 0
      AND p.locked_until IS NULL
  ) THEN
    RAISE EXCEPTION 'Samantha Aruelo IT10 login repair verification failed';
  END IF;

  RAISE NOTICE 'Samantha Aruelo IT10 login and enrollment repaired';
END $$;
