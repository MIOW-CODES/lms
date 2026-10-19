-- Correct Deonne Alexa Cabtalan's latest retake grant: revoke one extra attempt
-- from "Quiz — Programming with Arduino" and grant one for
-- "Quiz — Arduino Part 2" instead. Preserve any older unrelated allowance.

DO $$
DECLARE
  student_uuid uuid;
  old_quiz_uuid uuid;
  new_quiz_uuid uuid;
  reviewer_uuid uuid;
  old_before integer;
  old_after integer;
  new_before integer := 0;
  new_after integer;
  pending_count integer;
BEGIN
  SELECT id INTO student_uuid
  FROM public.profiles
  WHERE student_id = '2026-0101'
    AND lower(email) = 'deonnealexa.cabtalan@g.msuiit.edu.ph'
    AND role = 'student'
    AND deleted_at IS NULL;

  IF student_uuid IS NULL THEN
    RAISE EXCEPTION 'Active student profile not found for Deonne Alexa Cabtalan (2026-0101)';
  END IF;

  SELECT quiz.id INTO old_quiz_uuid
  FROM public.quizzes AS quiz
  JOIN public.courses AS course ON course.id = quiz.course_id
  WHERE upper(btrim(course.code)) = 'IT10'
    AND lower(btrim(quiz.title)) = lower('Quiz — Programming with Arduino')
    AND quiz.deleted_at IS NULL
  ORDER BY quiz.created_at DESC
  LIMIT 1;

  SELECT quiz.id INTO new_quiz_uuid
  FROM public.quizzes AS quiz
  JOIN public.courses AS course ON course.id = quiz.course_id
  WHERE upper(btrim(course.code)) = 'IT10'
    AND lower(btrim(quiz.title)) = lower('Quiz — Arduino Part 2')
    AND quiz.deleted_at IS NULL
  ORDER BY quiz.created_at DESC
  LIMIT 1;

  IF old_quiz_uuid IS NULL OR new_quiz_uuid IS NULL THEN
    RAISE EXCEPTION 'One or both target IT10 worksheets were not found';
  END IF;

  SELECT id INTO reviewer_uuid
  FROM public.profiles
  WHERE lower(email) = 'alan.vergara@g.msuiit.edu.ph'
    AND role IN ('teacher', 'admin')
    AND deleted_at IS NULL
  LIMIT 1;

  SELECT extra_attempts INTO old_before
  FROM public.quiz_retake_grants
  WHERE quiz_id = old_quiz_uuid
    AND student_id = student_uuid;

  IF old_before IS NULL OR old_before < 1 THEN
    RAISE EXCEPTION 'No Programming with Arduino retake grant exists to revoke';
  END IF;

  IF old_before = 1 THEN
    DELETE FROM public.quiz_retake_grants
    WHERE quiz_id = old_quiz_uuid
      AND student_id = student_uuid;
    old_after := 0;
  ELSE
    UPDATE public.quiz_retake_grants
    SET extra_attempts = extra_attempts - 1
    WHERE quiz_id = old_quiz_uuid
      AND student_id = student_uuid
    RETURNING extra_attempts INTO old_after;
  END IF;

  IF old_after <> old_before - 1 THEN
    RAISE EXCEPTION 'Programming with Arduino retake revocation verification failed';
  END IF;

  SELECT COALESCE(extra_attempts, 0) INTO new_before
  FROM public.quiz_retake_grants
  WHERE quiz_id = new_quiz_uuid
    AND student_id = student_uuid;

  SELECT count(*) INTO pending_count
  FROM public.quiz_retake_requests
  WHERE quiz_id = new_quiz_uuid
    AND student_id = student_uuid
    AND status = 'pending';

  IF pending_count > 0 THEN
    UPDATE public.quiz_retake_requests
    SET status = 'approved',
        reviewed_at = now(),
        reviewed_by = reviewer_uuid
    WHERE quiz_id = new_quiz_uuid
      AND student_id = student_uuid
      AND status = 'pending';
  ELSE
    INSERT INTO public.quiz_retake_grants (
      quiz_id, student_id, extra_attempts, granted_by
    ) VALUES (
      new_quiz_uuid, student_uuid, 1, reviewer_uuid
    )
    ON CONFLICT (quiz_id, student_id) DO UPDATE
      SET extra_attempts = public.quiz_retake_grants.extra_attempts + 1,
          granted_by = EXCLUDED.granted_by;
  END IF;

  SELECT extra_attempts INTO new_after
  FROM public.quiz_retake_grants
  WHERE quiz_id = new_quiz_uuid
    AND student_id = student_uuid;

  IF new_after IS NULL OR new_after <= new_before THEN
    RAISE EXCEPTION 'Arduino Part 2 retake grant verification failed';
  END IF;

  RAISE NOTICE 'Moved Deonne Cabtalan retake: Programming with Arduino % -> %, Arduino Part 2 % -> %',
    old_before, old_after, new_before, new_after;
END $$;
