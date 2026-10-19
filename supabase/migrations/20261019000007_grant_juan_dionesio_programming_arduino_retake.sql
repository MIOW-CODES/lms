-- Grant Juan Miguel Dionesio one additional attempt for the IT10 worksheet
-- "Quiz — Programming with Arduino". Approve his matching pending request when
-- one exists so the request history remains accurate; otherwise grant directly.

DO $$
DECLARE
  student_uuid uuid;
  quiz_uuid uuid;
  reviewer_uuid uuid;
  pending_count integer;
  attempts_before integer := 0;
  attempts_after integer;
BEGIN
  SELECT id INTO student_uuid
  FROM public.profiles
  WHERE lower(email) = 'juanmiguel.dionesio@g.msuiit.edu.ph'
    AND student_id = '2026-0105'
    AND role = 'student'
    AND deleted_at IS NULL;

  IF student_uuid IS NULL THEN
    RAISE EXCEPTION 'Active student profile not found for Juan Miguel Dionesio (2026-0105)';
  END IF;

  SELECT quiz.id INTO quiz_uuid
  FROM public.quizzes AS quiz
  JOIN public.courses AS course ON course.id = quiz.course_id
  WHERE upper(btrim(course.code)) = 'IT10'
    AND lower(btrim(quiz.title)) = lower('Quiz — Programming with Arduino')
    AND quiz.deleted_at IS NULL
  ORDER BY quiz.created_at DESC
  LIMIT 1;

  IF quiz_uuid IS NULL THEN
    RAISE EXCEPTION 'Active IT10 worksheet not found: Quiz — Programming with Arduino';
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

  SELECT count(*) INTO pending_count
  FROM public.quiz_retake_requests
  WHERE quiz_id = quiz_uuid
    AND student_id = student_uuid
    AND status = 'pending';

  IF pending_count > 0 THEN
    UPDATE public.quiz_retake_requests
    SET status = 'approved',
        reviewed_at = now(),
        reviewed_by = reviewer_uuid
    WHERE quiz_id = quiz_uuid
      AND student_id = student_uuid
      AND status = 'pending';
  ELSE
    INSERT INTO public.quiz_retake_grants (
      quiz_id, student_id, extra_attempts, granted_by
    ) VALUES (
      quiz_uuid, student_uuid, 1, reviewer_uuid
    )
    ON CONFLICT (quiz_id, student_id) DO UPDATE
      SET extra_attempts = public.quiz_retake_grants.extra_attempts + 1,
          granted_by = EXCLUDED.granted_by;
  END IF;

  SELECT extra_attempts INTO attempts_after
  FROM public.quiz_retake_grants
  WHERE quiz_id = quiz_uuid
    AND student_id = student_uuid;

  IF attempts_after IS NULL OR attempts_after <= attempts_before THEN
    RAISE EXCEPTION 'Retake grant verification failed for Juan Miguel Dionesio';
  END IF;

  RAISE NOTICE 'Granted one Programming with Arduino retake to Juan Miguel Dionesio: % -> % extra attempts',
    attempts_before, attempts_after;
END $$;
