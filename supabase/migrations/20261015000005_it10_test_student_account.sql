-- Migration: Create test student account it10@g.msuiit.edu.ph enrolled in IT10
DO $$
DECLARE
  v_course_id uuid;
  v_student_id uuid;
BEGIN
  -- 1. Get IT10 course ID
  SELECT id INTO v_course_id
  FROM public.courses
  WHERE code = 'IT10' OR code ILIKE '%IT 10%' OR title ILIKE '%IT 10%'
  ORDER BY (code = 'IT10') DESC, created_at ASC
  LIMIT 1;

  IF v_course_id IS NULL THEN
    RAISE EXCEPTION 'Course IT10 not found';
  END IF;

  -- 2. Create or update profile for it10@g.msuiit.edu.ph
  INSERT INTO public.profiles (
    email,
    username,
    student_id,
    full_name,
    role,
    pin,
    pin_must_change,
    grade_level,
    section
  ) VALUES (
    'it10@g.msuiit.edu.ph',
    'it10',
    'it10',
    'IT10 Test Student',
    'student',
    'it10',
    false,
    10,
    'Tester'
  )
  ON CONFLICT (email) DO UPDATE
    SET username = 'it10',
        student_id = 'it10',
        pin = 'it10',
        pin_hash = NULL,
        pin_must_change = false,
        role = 'student',
        failed_login_attempts = 0,
        locked_until = NULL,
        deleted_at = NULL
  RETURNING id INTO v_student_id;

  -- 3. Enroll into IT10
  INSERT INTO public.enrollments (student_id, course_id)
  VALUES (v_student_id, v_course_id)
  ON CONFLICT (student_id, course_id) DO NOTHING;

  RAISE NOTICE 'Created and enrolled it10@g.msuiit.edu.ph (id: %) in IT10 (id: %)', v_student_id, v_course_id;
END $$;
