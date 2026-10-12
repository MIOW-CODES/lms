-- Course: ICT1 — remove legacy all-caps 'QUIZ N' clones (TVE100 duplicates)
--
-- The TVE100 assessment clone left legacy quiz rows titled 'QUIZ 1'..'QUIZ 7'
-- (all-caps). The batch-2 reset (20261013000000) matched only mixed-case
-- 'Quiz 1'..'Quiz 7', so those clones survived and duplicate the weekly set:
-- the Worksheets page shows 13 cards instead of 9 (PRELIM + QUIZ 1-4 +
-- Quiz 1-7 + FINAL). These all-caps rows are exactly the "quiz 1-3" the user
-- asked to remove.
--
-- Soft-delete like the other legacy sets: rows and attempt history are
-- preserved but hidden. Idempotent (`deleted_at IS NULL` filter).
--
-- Double guard: title must be all-caps AND match 'QUIZ <digits>' — the live
-- weekly set is stored mixed-case ('Quiz 1'..'Quiz 7') and can never match
-- both conditions.
DO $$
DECLARE
  v_course uuid;
  v_n      int;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_remove_legacy_uppercase_quizzes: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  UPDATE public.quizzes
     SET deleted_at = now()
   WHERE course_id = v_course
     AND deleted_at IS NULL
     AND title = upper(title)          -- all-caps rows only
     AND title ~ '^QUIZ [0-9]+$';      -- legacy clone titles only
  GET DIAGNOSTICS v_n = ROW_COUNT;

  RAISE NOTICE 'ict1_remove_legacy_uppercase_quizzes: soft-deleted % legacy uppercase quiz row(s)', v_n;
END $$;
