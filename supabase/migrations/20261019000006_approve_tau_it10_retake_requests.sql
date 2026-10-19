-- Approve the pending worksheet-retake request(s) for the four named Grade 10
-- Tau students. The approval trigger creates/increments the matching per-quiz
-- grant, so access is limited to the worksheet each student requested.

DO $$
DECLARE
  target record;
  student_uuid uuid;
  reviewer_uuid uuid;
  pending_count integer;
  requested_quiz_count integer;
  requested_quiz_uuid uuid;
  approved_count integer := 0;
BEGIN
  SELECT id INTO reviewer_uuid
  FROM public.profiles
  WHERE lower(email) = 'alan.vergara@g.msuiit.edu.ph'
    AND role IN ('teacher', 'admin')
    AND deleted_at IS NULL
  LIMIT 1;

  SELECT count(DISTINCT request.quiz_id)
  INTO requested_quiz_count
  FROM public.quiz_retake_requests AS request
  JOIN public.profiles AS student ON student.id = request.student_id
  JOIN public.quizzes AS quiz ON quiz.id = request.quiz_id
  JOIN public.courses AS course ON course.id = quiz.course_id
  WHERE student.student_id IN ('2026-0099', '2026-0103', '2026-0101', '2026-0107')
    AND request.status = 'pending'
    AND quiz.deleted_at IS NULL
    AND upper(btrim(course.code)) = 'IT10';

  -- Fresh installations have no historical student requests to approve.
  IF requested_quiz_count = 0 THEN
    RAISE NOTICE 'No pending Tau IT10 retake requests; skipping historical approval';
    RETURN;
  END IF;

  IF requested_quiz_count <> 1 THEN
    RAISE EXCEPTION
      'Expected one common requested IT10 worksheet; found % distinct worksheets',
      requested_quiz_count;
  END IF;

  SELECT request.quiz_id
  INTO requested_quiz_uuid
  FROM public.quiz_retake_requests AS request
  JOIN public.profiles AS student ON student.id = request.student_id
  JOIN public.quizzes AS quiz ON quiz.id = request.quiz_id
  JOIN public.courses AS course ON course.id = quiz.course_id
  WHERE student.student_id IN ('2026-0099', '2026-0103', '2026-0101', '2026-0107')
    AND request.status = 'pending'
    AND quiz.deleted_at IS NULL
    AND upper(btrim(course.code)) = 'IT10'
  LIMIT 1;

  FOR target IN
    SELECT * FROM (VALUES
      ('2026-0099', 'Aaron Gabriel Banaag'),
      ('2026-0103', 'Makayla Sophie Caunda'),
      ('2026-0101', 'Deonne Alexa Cabtalan'),
      ('2026-0107', 'Gleen Patrick Fuentes')
    ) AS requested(student_id, full_name)
  LOOP
    SELECT id INTO student_uuid
    FROM public.profiles
    WHERE student_id = target.student_id
      AND role = 'student'
      AND deleted_at IS NULL;

    IF student_uuid IS NULL THEN
      RAISE EXCEPTION 'Active student profile not found: % (%)',
        target.full_name, target.student_id;
    END IF;

    SELECT count(*) INTO pending_count
    FROM public.quiz_retake_requests AS request
    WHERE request.student_id = student_uuid
      AND request.status = 'pending'
      AND request.quiz_id = requested_quiz_uuid;

    IF pending_count > 0 THEN
      UPDATE public.quiz_retake_requests
      SET status = 'approved',
          reviewed_at = now(),
          reviewed_by = reviewer_uuid
      WHERE student_id = student_uuid
        AND status = 'pending'
        AND quiz_id = requested_quiz_uuid;

      GET DIAGNOSTICS pending_count = ROW_COUNT;
      approved_count := approved_count + pending_count;
    ELSE
      INSERT INTO public.quiz_retake_grants (
        quiz_id, student_id, extra_attempts, granted_by
      ) VALUES (
        requested_quiz_uuid, student_uuid, 1, reviewer_uuid
      )
      ON CONFLICT (quiz_id, student_id) DO UPDATE
        SET extra_attempts = public.quiz_retake_grants.extra_attempts + 1,
            granted_by = EXCLUDED.granted_by;
      approved_count := approved_count + 1;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.quiz_retake_grants
      WHERE quiz_id = requested_quiz_uuid
        AND student_id = student_uuid
        AND extra_attempts > 0
    ) THEN
      RAISE EXCEPTION 'Retake grant verification failed for % (%)',
        target.full_name, target.student_id;
    END IF;

    RAISE NOTICE 'Granted IT10 worksheet retake for % (%)',
      target.full_name, target.student_id;
  END LOOP;

  IF approved_count < 4 THEN
    RAISE EXCEPTION 'Expected at least 4 approvals; approved %', approved_count;
  END IF;

  RAISE NOTICE 'Approved % requested IT10 worksheet retake(s) for 4 Tau students',
    approved_count;
END $$;
