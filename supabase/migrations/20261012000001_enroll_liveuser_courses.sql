-- Enroll LiveUser (test@g.msuiit.edu.ph) in all courses.
-- Purpose: Enable seamless manual checks and live testing in student view.

DO $$
DECLARE
  v_liveuser_id uuid;
  v_enrolled int := 0;
BEGIN
  SELECT id INTO v_liveuser_id
    FROM public.profiles
   WHERE lower(coalesce(email, '')) = 'test@g.msuiit.edu.ph';

  IF v_liveuser_id IS NOT NULL THEN
    INSERT INTO public.enrollments (student_id, course_id)
    SELECT v_liveuser_id, c.id
      FROM public.courses c
    ON CONFLICT (student_id, course_id) DO NOTHING;

    GET DIAGNOSTICS v_enrolled = ROW_COUNT;
    RAISE NOTICE 'Enrolled LiveUser (%) in % courses', v_liveuser_id, v_enrolled;
  END IF;
END $$;
