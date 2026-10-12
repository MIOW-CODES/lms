-- 20261012000010: Remove the duplicate "Lecture TLE 105" course (it duplicates ICT1).
--
-- WHY: 20261006000001_lecture_b8_v3_fixes.sql (and PRODUCTION_APPLY_V3.sql)
-- cloned ICT1's quizzes/assignments into the lecture course (code 'TLE 105' /
-- title 'LECTURE_TLE 105%') and enrolled the 45 B8 lecture students there.
-- That course is a redundant duplicate of ICT1 and is being removed. ICT1 and
-- TVE100 are NEVER touched.
--
-- COURSE MATCH: resolved at run time by code 'TLE 105' OR title
-- ILIKE 'LECTURE_TLE 105%', explicitly EXCLUDING code 'ICT1' / 'TVE100'. The
-- id is never hard-coded / guessed. If no such course exists, a NOTICE is
-- raised and nothing is deleted (idempotent).
--
-- FK-SAFE ORDER: children before parents. Every course_id / quiz_id /
-- assignment_id reference in this schema is ON DELETE CASCADE (see
-- 20260822144314, 20261003000001, 20261011000000, 20260825084204,
-- 20260923000002, 20260831000005), so the final DELETE FROM public.courses is
-- a backstop for anything not enumerated. The explicit deletes below give
-- per-table row counts and remove soft-deleted (deleted_at) rows too, since the
-- whole course is going away.
--
-- NOT TOUCHED: attendance_logs is NOT course-scoped (keys only on student_id),
-- so it is intentionally left alone. notification_logs / audit_logs carry no
-- course FK and are left as-is.
--
-- NOTE: the purely-lecture create/resync sections of PRODUCTION_APPLY_V3.sql
-- (the (4a)/(4b)/(4d) blocks) have been neutralized so future production runs
-- cannot recreate/resync this course.
-- =============================================================================

DO $rm_lect$
DECLARE
  v_lect     uuid;               -- the lecture course to remove
  v_code     text;
  v_title    text;
  v_quiz_ids uuid[] := ARRAY[]::uuid[];   -- quizzes of the lecture course (for child deletes)
  v_asg_ids  uuid[] := ARRAY[]::uuid[];   -- assignments of the lecture course
  v_n        integer;
BEGIN
  -- ── 0. Resolve the lecture course (never guessed; never ICT1/TVE100) ──────
  SELECT id, code, title INTO v_lect, v_code, v_title
  FROM public.courses
  WHERE code = 'TLE 105'
    AND code IS DISTINCT FROM 'ICT1'
    AND code IS DISTINCT FROM 'TVE100'
  ORDER BY created_at
  LIMIT 1;

  IF v_lect IS NULL THEN
    SELECT id, code, title INTO v_lect, v_code, v_title
    FROM public.courses
    WHERE title ILIKE 'LECTURE_TLE 105%'
      AND code IS DISTINCT FROM 'ICT1'
      AND code IS DISTINCT FROM 'TVE100'
    ORDER BY created_at
    LIMIT 1;
    IF v_lect IS NOT NULL THEN
      RAISE NOTICE 'remove_lecture_tle105: matched lecture course by title ILIKE LECTURE_TLE 105%%';
    END IF;
  END IF;

  IF v_lect IS NULL THEN
    RAISE NOTICE 'remove_lecture_tle105: lecture course (code TLE 105 OR title ILIKE LECTURE_TLE 105%%) not found - nothing to do (skip)';
    RETURN;
  END IF;

  RAISE NOTICE 'remove_lecture_tle105: removing lecture course id=% code=% title=%', v_lect, v_code, v_title;

  -- Collect quiz + assignment ids up front for child-scoped deletes.
  SELECT COALESCE(array_agg(id), ARRAY[]::uuid[]) INTO v_quiz_ids FROM public.quizzes     WHERE course_id = v_lect;
  SELECT COALESCE(array_agg(id), ARRAY[]::uuid[]) INTO v_asg_ids  FROM public.assignments WHERE course_id = v_lect;

  -- ── 1. course_meeting_members (child of course_meetings) ──────────────────
  DELETE FROM public.course_meeting_members m
  USING public.course_meetings cm
  WHERE m.meeting_id = cm.id AND cm.course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: course_meeting_members deleted %', v_n;

  -- ── 2. course_meetings ────────────────────────────────────────────────────
  DELETE FROM public.course_meetings WHERE course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: course_meetings deleted %', v_n;

  -- ── 3. course_sections ────────────────────────────────────────────────────
  DELETE FROM public.course_sections WHERE course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: course_sections deleted %', v_n;

  -- ── 4. quiz_score_overrides (child of quizzes) ────────────────────────────
  DELETE FROM public.quiz_score_overrides WHERE quiz_id = ANY (v_quiz_ids);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: quiz_score_overrides deleted %', v_n;

  -- ── 5. quiz_retake_grants (child of quizzes) ──────────────────────────────
  DELETE FROM public.quiz_retake_grants WHERE quiz_id = ANY (v_quiz_ids);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: quiz_retake_grants deleted %', v_n;

  -- ── 6. quiz_attempts (child of quizzes) ───────────────────────────────────
  DELETE FROM public.quiz_attempts WHERE quiz_id = ANY (v_quiz_ids);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: quiz_attempts deleted %', v_n;

  -- ── 7. quiz_questions (child of quizzes) ──────────────────────────────────
  DELETE FROM public.quiz_questions WHERE quiz_id = ANY (v_quiz_ids);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: quiz_questions deleted %', v_n;

  -- ── 8. quizzes (parent; after its children) ───────────────────────────────
  DELETE FROM public.quizzes WHERE course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: quizzes deleted %', v_n;

  -- ── 9. submission_files (child of submissions) ────────────────────────────
  DELETE FROM public.submission_files f
  USING public.submissions s
  WHERE f.submission_id = s.id AND s.assignment_id = ANY (v_asg_ids);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: submission_files deleted %', v_n;

  -- ── 10. submissions (child of assignments) ────────────────────────────────
  DELETE FROM public.submissions WHERE assignment_id = ANY (v_asg_ids);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: submissions deleted %', v_n;

  -- ── 11. assignments (parent; after its children) ──────────────────────────
  DELETE FROM public.assignments WHERE course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: assignments deleted %', v_n;

  -- ── 12. tos (course-scoped; items jsonb only softly references quiz_id) ───
  DELETE FROM public.tos WHERE course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: tos deleted %', v_n;

  -- ── 13. grades ────────────────────────────────────────────────────────────
  DELETE FROM public.grades WHERE course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: grades deleted %', v_n;

  -- ── 14. enrollments ───────────────────────────────────────────────────────
  DELETE FROM public.enrollments WHERE course_id = v_lect;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: enrollments deleted %', v_n;

  -- ── 15. the course row itself (backstop: ON DELETE CASCADE would also have
  --        caught any dependent row not enumerated above). Guarded so ICT1 /
  --        TVE100 can never be deleted here.
  DELETE FROM public.courses
  WHERE id = v_lect
    AND code IS DISTINCT FROM 'ICT1'
    AND code IS DISTINCT FROM 'TVE100';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'remove_lecture_tle105: courses deleted %', v_n;

  RAISE NOTICE 'remove_lecture_tle105: done - lecture course % removed', v_lect;
END $rm_lect$;
