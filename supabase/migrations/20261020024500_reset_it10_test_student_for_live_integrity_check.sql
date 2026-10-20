-- Restore only the dedicated IT10 test student's documented test login so a
-- live integrity check can run without using a real student's account.
DO $it10_test_student_login$
DECLARE
  v_profile_id uuid;
  v_profile_count integer;
  v_course_id uuid;
  v_course_count integer;
BEGIN
  SELECT count(*) INTO v_profile_count
    FROM public.profiles
   WHERE lower(btrim(email)) = 'it10@g.msuiit.edu.ph'
     AND role = 'student';

  IF v_profile_count <> 1 THEN
    RAISE EXCEPTION 'IT10 live test setup stopped: expected one dedicated IT10 test student, found %', v_profile_count;
  END IF;

  SELECT id INTO v_profile_id
    FROM public.profiles
   WHERE lower(btrim(email)) = 'it10@g.msuiit.edu.ph'
     AND role = 'student';

  SELECT count(*) INTO v_course_count
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  IF v_course_count <> 1 THEN
    RAISE EXCEPTION 'IT10 live test setup stopped: expected one IT10 course, found %', v_course_count;
  END IF;

  SELECT id INTO v_course_id
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  UPDATE public.profiles
     SET username = 'it10',
         student_id = 'it10',
         full_name = 'IT10 Test Student',
         pin = 'it10',
         pin_hash = NULL,
         pin_must_change = false,
         failed_login_attempts = 0,
         locked_until = NULL,
         deleted_at = NULL
   WHERE id = v_profile_id;

  INSERT INTO public.enrollments (student_id, course_id)
  VALUES (v_profile_id, v_course_id)
  ON CONFLICT (student_id, course_id) DO NOTHING;

  DELETE FROM public.auth_rate_limits
   WHERE bucket_key IN (
     encode(extensions.digest('login:ident:it10', 'sha256'), 'hex'),
     encode(extensions.digest('login:profile:' || v_profile_id::text, 'sha256'), 'hex'),
     encode(extensions.digest('pin:' || v_profile_id::text, 'sha256'), 'hex'),
     encode(extensions.digest('secret:' || v_profile_id::text, 'sha256'), 'hex')
   );

  RAISE NOTICE 'Restored the dedicated IT10 test student's documented test login and enrollment';
END;
$it10_test_student_login$;
