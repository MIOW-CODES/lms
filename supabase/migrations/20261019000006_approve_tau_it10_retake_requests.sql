-- Approve the pending worksheet-retake request(s) for the four named Grade 10
-- Tau students. The approval trigger creates/increments the matching per-quiz
-- grant, so access is limited to the worksheet each student requested.

DO $$
DECLARE
  target record;
  student_uuid uuid;
  reviewer_uuid uuid;
  pending_count integer;
  approved_count integer := 0;
BEGIN
  SELECT id INTO reviewer_uuid
  FROM public.profiles
  WHERE lower(email) = 'alan.vergara@g.msuiit.edu.ph'
    AND role IN ('teacher', 'admin')
    AND deleted_at IS NULL
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
    JOIN public.quizzes AS quiz ON quiz.id = request.quiz_id
    JOIN public.courses AS course ON course.id = quiz.course_id
    WHERE request.student_id = student_uuid
      AND request.status = 'pending'
      AND quiz.deleted_at IS NULL
      AND upper(btrim(course.code)) = 'IT10';

    IF pending_count = 0 THEN
      RAISE EXCEPTION 'No pending IT10 worksheet retake request for % (%)',
        target.full_name, target.student_id;
    END IF;

    UPDATE public.quiz_retake_requests AS request
    SET status = 'approved',
        reviewed_at = now(),
        reviewed_by = reviewer_uuid
    FROM public.quizzes AS quiz, public.courses AS course
    WHERE request.student_id = student_uuid
      AND request.status = 'pending'
      AND request.quiz_id = quiz.id
      AND quiz.course_id = course.id
      AND quiz.deleted_at IS NULL
      AND upper(btrim(course.code)) = 'IT10';

    GET DIAGNOSTICS pending_count = ROW_COUNT;
    approved_count := approved_count + pending_count;
    RAISE NOTICE 'Approved % IT10 retake request(s) for % (%)',
      pending_count, target.full_name, target.student_id;
  END LOOP;

  IF approved_count < 4 THEN
    RAISE EXCEPTION 'Expected at least 4 approvals; approved %', approved_count;
  END IF;

  RAISE NOTICE 'Approved % requested IT10 worksheet retake(s) for 4 Tau students',
    approved_count;
END $$;
