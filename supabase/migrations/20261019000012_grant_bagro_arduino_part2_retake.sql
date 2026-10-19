-- Grant Shahanne Lea Bagro one additional attempt for the IT10 worksheet
-- "Quiz — Arduino Part 2".

DO $$
DECLARE
  student_uuid uuid;
  quiz_uuid uuid;
  reviewer_uuid uuid;
  attempts_before integer := 0;
  attempts_after integer;
BEGIN
  SELECT id INTO student_uuid
  FROM public.profiles
  WHERE student_id = '2026-0098'
    AND lower(email) = 'shahannelea.bagro@g.msuiit.edu.ph'
    AND role = 'student'
    AND deleted_at IS NULL;

  IF student_uuid IS NULL THEN
    RAISE EXCEPTION 'Active student profile not found for Shahanne Lea Bagro (2026-0098)';
  END IF;

  SELECT quiz.id INTO quiz_uuid
  FROM public.quizzes AS quiz
  JOIN public.courses AS course ON course.id = quiz.course_id
  WHERE upper(btrim(course.code)) = 'IT10'
    AND lower(btrim(quiz.title)) = lower('Quiz — Arduino Part 2')
    AND quiz.deleted_at IS NULL
  ORDER BY quiz.created_at DESC
  LIMIT 1;

  IF quiz_uuid IS NULL THEN
    RAISE EXCEPTION 'Active IT10 worksheet not found: Quiz — Arduino Part 2';
  END IF;

  SELECT id INTO reviewer_uuid
  FROM public.profiles
  WHERE lower(email) = 'alan.vergara@g.msuiit.edu.ph'
    AND role IN ('teacher', 'admin')
    AND deleted_at IS NULL
  LIMIT 1;

  SELECT COALESCE(extra_attempts, 0) INTO attempts_before
  FROM public.quiz_retake_grants
  WHERE quiz_id = quiz_uuid
    AND student_id = student_uuid;

  INSERT INTO public.quiz_retake_grants (
    quiz_id, student_id, extra_attempts, granted_by
  ) VALUES (
    quiz_uuid, student_uuid, 1, reviewer_uuid
  )
  ON CONFLICT (quiz_id, student_id) DO UPDATE
    SET extra_attempts = public.quiz_retake_grants.extra_attempts + 1,
        granted_by = EXCLUDED.granted_by;

  SELECT extra_attempts INTO attempts_after
  FROM public.quiz_retake_grants
  WHERE quiz_id = quiz_uuid
    AND student_id = student_uuid;

  IF attempts_after IS NULL OR attempts_after <> attempts_before + 1 THEN
    RAISE EXCEPTION 'Arduino Part 2 retake grant verification failed for Shahanne Lea Bagro';
  END IF;

  RAISE NOTICE 'Granted Shahanne Lea Bagro another Arduino Part 2 attempt: % -> % extra attempts',
    attempts_before, attempts_after;
END $$;
