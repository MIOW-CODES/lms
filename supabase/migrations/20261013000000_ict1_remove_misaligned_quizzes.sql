-- Course: ICT1 — remove misaligned Quiz 1–7 set (soft delete)
--
-- The currently-active ICT1 quizzes titled 'Quiz 1'..'Quiz 7' carry misaligned
-- content (wrong course material and stale attempt history). Soft-delete all of
-- them so the new TVE100 slide-based quiz set (Weeks 1–4) can be seeded cleanly
-- by the migrations that follow this one.
--
-- Safety rules:
--   * Scope is EXACTLY title IN ('Quiz 1','Quiz 2','Quiz 3','Quiz 4','Quiz 5',
--     'Quiz 6','Quiz 7') on the ICT1 course (code = 'ICT1', never a hard-coded
--     uuid) with deleted_at IS NULL.
--   * 'PRELIM EXAMINATION…' and 'FINAL EXAMINATION…' rows are NEVER touched
--     (their titles do not match, and they have attempt history that must be
--     preserved).
--   * Soft delete only (deleted_at = now()); rows and attempt history remain.
--   * Fully idempotent — re-running matches nothing and deletes nothing.
DO $$
DECLARE
  v_course uuid;
  v_titles constant text[] := ARRAY[
    'Quiz 1', 'Quiz 2', 'Quiz 3', 'Quiz 4', 'Quiz 5', 'Quiz 6', 'Quiz 7'
  ];
  v_title  text;
  v_n      int;
  v_total  int := 0;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_remove_misaligned_quizzes: course code ICT1 not found — nothing to do';
    RETURN;
  END IF;

  FOREACH v_title IN ARRAY v_titles LOOP
    UPDATE public.quizzes
       SET deleted_at = now()
     WHERE course_id = v_course
       AND title = v_title
       AND deleted_at IS NULL;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n > 0 THEN
      RAISE NOTICE 'ict1_remove_misaligned_quizzes: soft-deleted % active ICT1 quiz(zes) titled "%"', v_n, v_title;
    END IF;
    v_total := v_total + v_n;
  END LOOP;

  RAISE NOTICE 'ict1_remove_misaligned_quizzes: done — soft-deleted % misaligned ICT1 quiz(zes) total (exams untouched)', v_total;
END $$;
