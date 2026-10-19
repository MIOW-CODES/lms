-- Grant the requested IT10 worksheet retakes for Sein Mikel James Aquino and
-- Shahanne Lea Bagro. Matching pending requests are approved when present;
-- otherwise the per-student grant is incremented directly.

DO $$
DECLARE
  target record;
  student_uuid uuid;
  quiz_uuid uuid;
  reviewer_uuid uuid;
  pending_count integer;
  attempts_before integer;
  attempts_after integer;
  granted_count integer := 0;
BEGIN
  SELECT id INTO reviewer_uuid
  FROM public.profiles
  WHERE lower(email) = 'alan.vergara@g.msuiit.edu.ph'
    AND role IN ('teacher', 'admin')
    AND deleted_at IS NULL
  LIMIT 1;

  FOR target IN
    SELECT * FROM (VALUES
      ('2026-0094', 'seinmikeljames.aquino@g.msuiit.edu.ph', 'Sein Mikel James Aquino', 'Quiz — Resistor Color Code'),
      ('2026-0094', 'seinmikeljames.aquino@g.msuiit.edu.ph', 'Sein Mikel James Aquino', 'Quiz — Programming with Arduino'),
      ('2026-0098', 'shahannelea.bagro@g.msuiit.edu.ph', 'Shahanne Lea Bagro', 'Quiz — Arduino Part 2')
    ) AS requested(student_id, email, full_name, quiz_title)
  LOOP
    student_uuid := NULL;
    quiz_uuid := NULL;
    attempts_before := 0;
    attempts_after := NULL;

    SELECT id INTO student_uuid
    FROM public.profiles
    WHERE student_id = target.student_id
      AND lower(email) = target.email
      AND role = 'student'
      AND deleted_at IS NULL;

    IF student_uuid IS NULL THEN
      RAISE EXCEPTION 'Active student profile not found: % (%)',
        target.full_name, target.student_id;
    END IF;

    SELECT quiz.id INTO quiz_uuid
    FROM public.quizzes AS quiz
    JOIN public.courses AS course ON course.id = quiz.course_id
    WHERE upper(btrim(course.code)) = 'IT10'
      AND lower(btrim(quiz.title)) = lower(target.quiz_title)
      AND quiz.deleted_at IS NULL
    ORDER BY quiz.created_at DESC
    LIMIT 1;

    IF quiz_uuid IS NULL THEN
      RAISE EXCEPTION 'Active IT10 worksheet not found: %', target.quiz_title;
    END IF;

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
      RAISE EXCEPTION 'Retake grant verification failed for % on %',
        target.full_name, target.quiz_title;
    END IF;

    granted_count := granted_count + 1;
    RAISE NOTICE 'Granted retake for % on %: % -> % extra attempts',
      target.full_name, target.quiz_title, attempts_before, attempts_after;
  END LOOP;

  IF granted_count <> 3 THEN
    RAISE EXCEPTION 'Expected 3 verified retake grants; found %', granted_count;
  END IF;
END $$;
