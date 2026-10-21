-- Restore Sittie Ainah Abdullah's IT10 temporary login and clear lockouts.
-- The temporary PIN is rotated to a private PIN at the next successful login.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

DO $sittie_ainah_login$
DECLARE
  v_profile_id uuid;
  v_profile_count integer;
  v_course_id uuid;
  v_course_count integer;
BEGIN
  SELECT count(*) INTO v_profile_count
    FROM public.profiles
   WHERE student_id = '2026-0001'
      OR lower(btrim(email)) = 'sittieainah.abdullah@g.msuiit.edu.ph';

  IF v_profile_count > 1 THEN
    RAISE EXCEPTION 'Sittie Ainah login repair stopped: found % matching profiles', v_profile_count;
  END IF;

  IF v_profile_count = 0 THEN
    INSERT INTO public.profiles (
      student_id, email, pin, pin_hash, full_name, role,
      grade_level, section, pin_must_change, failed_login_attempts, locked_until
    ) VALUES (
      '2026-0001',
      'sittieainah.abdullah@g.msuiit.edu.ph',
      '1234',
      NULL,
      'Sittie Ainah Abdullah',
      'student',
      10,
      'Omega',
      true,
      0,
      NULL
    )
    RETURNING id INTO v_profile_id;
  ELSE
    SELECT id INTO v_profile_id
      FROM public.profiles
     WHERE student_id = '2026-0001'
        OR lower(btrim(email)) = 'sittieainah.abdullah@g.msuiit.edu.ph';

    UPDATE public.profiles
       SET student_id = '2026-0001',
           email = 'sittieainah.abdullah@g.msuiit.edu.ph',
           role = 'student',
           grade_level = 10,
           section = 'Omega',
           deleted_at = NULL,
           pin = '1234',
           pin_hash = NULL,
           pin_must_change = true,
           failed_login_attempts = 0,
           locked_until = NULL
     WHERE id = v_profile_id;
  END IF;

  SELECT count(*) INTO v_course_count
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  IF v_course_count <> 1 THEN
    RAISE EXCEPTION 'Sittie Ainah login repair stopped: expected one IT10 course, found %', v_course_count;
  END IF;

  SELECT id INTO v_course_id
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  INSERT INTO public.enrollments (student_id, course_id)
  VALUES (v_profile_id, v_course_id)
  ON CONFLICT (student_id, course_id) DO NOTHING;

  WITH profile AS (
    SELECT id, student_id, email, username, employee_id
      FROM public.profiles
     WHERE id = v_profile_id
  ), raw_keys AS (
    SELECT 'pin:' || id::text AS value FROM profile
    UNION ALL SELECT 'secret:' || id::text FROM profile
    UNION ALL SELECT 'login:profile:' || id::text FROM profile
    UNION ALL SELECT 'login:ident:' || lower(student_id) FROM profile WHERE student_id IS NOT NULL
    UNION ALL SELECT 'login:ident:' || lower(email) FROM profile WHERE email IS NOT NULL
    UNION ALL SELECT 'login:ident:' || lower(username) FROM profile WHERE username IS NOT NULL
    UNION ALL SELECT 'login:ident:' || lower(employee_id) FROM profile WHERE employee_id IS NOT NULL
  ), bucket_keys AS (
    SELECT encode(extensions.digest(value, 'sha256'), 'hex') AS value
      FROM raw_keys
  )
  DELETE FROM public.auth_rate_limits AS limits
   USING bucket_keys
   WHERE limits.bucket_key = bucket_keys.value;

  IF NOT EXISTS (
    SELECT 1
      FROM public.profiles p
      JOIN public.enrollments e ON e.student_id = p.id
     WHERE p.id = v_profile_id
       AND e.course_id = v_course_id
       AND p.student_id = '2026-0001'
       AND lower(btrim(p.email)) = 'sittieainah.abdullah@g.msuiit.edu.ph'
       AND p.role = 'student'
       AND p.section = 'Omega'
       AND p.pin = '1234'
       AND p.pin_hash IS NULL
       AND p.pin_must_change = true
       AND coalesce(p.failed_login_attempts, 0) = 0
       AND p.locked_until IS NULL
  ) THEN
    RAISE EXCEPTION 'Sittie Ainah IT10 login repair verification failed';
  END IF;

  RAISE NOTICE 'Restored Sittie Ainah IT10 login and cleared login lockouts';
END;
$sittie_ainah_login$;
