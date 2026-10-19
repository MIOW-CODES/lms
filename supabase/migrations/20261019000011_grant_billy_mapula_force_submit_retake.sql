-- Grant Billy Johnwel Mapula a retake for his latest IT10 attempt that was
-- automatically submitted after a severe integrity event. Resolve the quiz
-- from the recorded attempt so the grant cannot land on a different worksheet.

DO $$
DECLARE
  student_uuid uuid;
  quiz_uuid uuid;
  quiz_title text;
  attempt_uuid uuid;
  reviewer_uuid uuid;
  pending_count integer;
  attempts_before integer := 0;
  attempts_after integer;
BEGIN
  SELECT id INTO student_uuid
  FROM public.profiles
  WHERE student_id = '2026-0112'
    AND lower(email) = 'billyjohnwel.mapula@g.msuiit.edu.ph'
    AND role = 'student'
    AND deleted_at IS NULL;

  IF student_uuid IS NULL THEN
    RAISE EXCEPTION 'Active student profile not found for Billy Johnwel Mapula (2026-0112)';
  END IF;

  SELECT attempt.id, attempt.quiz_id, quiz.title
  INTO attempt_uuid, quiz_uuid, quiz_title
  FROM public.quiz_attempts AS attempt
  JOIN public.quizzes AS quiz ON quiz.id = attempt.quiz_id
  JOIN public.courses AS course ON course.id = quiz.course_id
  WHERE attempt.student_id = student_uuid
    AND upper(btrim(course.code)) = 'IT10'
    AND quiz.deleted_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM jsonb_array_elements(COALESCE(attempt.tab_switches, '[]'::jsonb)) AS event
      WHERE event->>'type' IN ('devtools', 'fullscreenchange', 'paste')
    )
  ORDER BY attempt.created_at DESC, attempt.attempt_number DESC
  LIMIT 1;

  IF attempt_uuid IS NULL OR quiz_uuid IS NULL THEN
    -- A fresh installation has no historical attempt to recover.
    RAISE NOTICE 'No force-submitted IT10 attempt found; skipping historical recovery';
    RETURN;
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
    RAISE EXCEPTION 'Force-submit retake grant verification failed for Billy Johnwel Mapula';
  END IF;

  RAISE NOTICE 'Granted Billy Johnwel Mapula a retake for force-submitted worksheet "%" (attempt %): % -> % extra attempts',
    quiz_title, attempt_uuid, attempts_before, attempts_after;
END $$;
