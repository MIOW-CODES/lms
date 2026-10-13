-- Cleanup: remove over-broad seed enrollments that made students "see courses
-- that are not theirs".
--
-- Root cause (data, not code): every course/quiz/assignment read is correctly
-- enrollment-gated server-side, but two seeds enrolled far too many students:
--   * 20260901000000_grade10_seed.sql   -> IT10 to EVERY student (should be Grade 10)
--   * 20261010000009_seed_iae106_*.sql  -> IAE 106 to EVERY student (comment said
--                                          a College-2nd-Yr / BTLED / B8 cohort)
-- Those seed files are now fixed so a FRESH database re-seeds the correct
-- cohort, but they already ran on existing databases — this migration repairs
-- the data that is already in place.
--
-- Scope: ONLY the two course codes below. ICT1, TVE100, IT10's legitimate
-- grade-10 roster, and every other course are never touched. Staff enrollments
-- are never touched (`role = 'student'`). Idempotent — re-running removes 0 rows.
DO $$
DECLARE
  v_it10 uuid;
  v_iae  uuid;
  v_removed int := 0;
BEGIN
  SELECT id INTO v_it10 FROM public.courses WHERE code = 'IT10';
  SELECT id INTO v_iae  FROM public.courses WHERE code = 'IAE 106';

  -- 1) IT10 is a Grade 10 subject: keep only grade_level = 10 students.
  --    (Test accounts are preserved so the deliberate live-testing setup in
  --    20261012000001_enroll_liveuser_courses.sql keeps working.)
  IF v_it10 IS NOT NULL THEN
    DELETE FROM public.enrollments e
    USING public.profiles p
    WHERE e.course_id = v_it10
      AND e.student_id = p.id
      AND p.role = 'student'
      AND coalesce(p.grade_level, -1) <> 10
      AND coalesce(p.student_id, '') <> '2026-0000'
      AND lower(coalesce(p.email, '')) <> 'test@g.msuiit.edu.ph';
    GET DIAGNOSTICS v_removed = ROW_COUNT;
    RAISE NOTICE 'cleanup_overbroad_enrollments: removed % IT10 enrollment(s) outside Grade 10', v_removed;
  ELSE
    RAISE NOTICE 'cleanup_overbroad_enrollments: course IT10 not found — skipped';
  END IF;

  -- 2) IAE 106 is the College 2nd-Year / BTLED / B8 electronics course: keep
  --    grade_level = 14 (College 2nd Year), section ILIKE 'BTLED%', section
  --    'B8', and the known demo/test accounts. Remove everyone else.
  IF v_iae IS NOT NULL THEN
    DELETE FROM public.enrollments e
    USING public.profiles p
    WHERE e.course_id = v_iae
      AND e.student_id = p.id
      AND p.role = 'student'
      AND coalesce(p.grade_level, -1) <> 14
      AND coalesce(p.section, '') NOT ILIKE 'BTLED%'
      AND coalesce(p.section, '') <> 'B8'
      AND coalesce(p.student_id, '') <> '2026-0000'
      AND lower(coalesce(p.email, '')) <> 'test@g.msuiit.edu.ph';
    GET DIAGNOSTICS v_removed = ROW_COUNT;
    RAISE NOTICE 'cleanup_overbroad_enrollments: removed % IAE 106 enrollment(s) outside the BTLED/B8/2nd-year cohort', v_removed;
  ELSE
    RAISE NOTICE 'cleanup_overbroad_enrollments: course IAE 106 not found — skipped';
  END IF;
END $$;

-- Undo (manual, if a removed student should be re-enrolled):
--   INSERT INTO public.enrollments (student_id, course_id)
--   SELECT p.id, c.id FROM public.profiles p, public.courses c
--   WHERE c.code IN ('IT10', 'IAE 106') AND p.id = '<profile-uuid>'
--   ON CONFLICT (student_id, course_id) DO NOTHING;
