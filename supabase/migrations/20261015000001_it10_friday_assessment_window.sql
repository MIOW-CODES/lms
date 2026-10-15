-- IT10 1st Quarter assessments — Friday-only window + release policy.
--
-- User decisions (2026-10-15):
--   * The exam AND the three quizzes are available ONLY on the scheduled
--     date/time: Friday, 16 Oct 2026, 08:00–10:00 (Asia/Manila, GMT+8).
--   * The "1st Quarter Exam" is a SINGLE attempt (no retakes).
--   * Students SEE their scores but NOT the answer key / correct answers.
--
-- Availability + gating are enforced server-side by requireOpen/hasOpened
-- (src/lib/server/availability.ts) and requireEnrollment; timestamptz compares
-- correctly against the UTC instant, so the +08 window is exact regardless of
-- the server's timezone. Submissions outside the window are hard-blocked.
--
-- Idempotent: plain UPDATEs keyed by course + deleted_at IS NULL; re-running is
-- a no-op. Only IT10 is touched.
DO $$
DECLARE
  v_course uuid;
  v_open   timestamptz := '2026-10-16 08:00:00+08'::timestamptz;
  v_close  timestamptz := '2026-10-16 10:00:00+08'::timestamptz;
  v_n      int;
BEGIN
  SELECT id INTO v_course
    FROM public.courses
   WHERE code = 'IT10'
   ORDER BY created_at
   LIMIT 1;
  IF v_course IS NULL THEN
    RAISE NOTICE 'it10_friday_window: course IT10 not found — skipping';
    RETURN;
  END IF;

  -- 1) Friday-only window + scores visible, answer key withheld (exam + quizzes).
  UPDATE public.quizzes
     SET opens_at            = v_open,
         closes_at           = v_close,
         score_released      = true,
         answer_key_released = false
   WHERE course_id = v_course
     AND deleted_at IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'it10_friday_window: applied Fri 2026-10-16 08:00-10:00 (+08) window and score/answer-key policy to % worksheet(s)', v_n;

  -- 2) The 1st Quarter Exam is a single attempt.
  UPDATE public.quizzes
     SET allow_retake = false,
         max_attempts = 1
   WHERE course_id = v_course
     AND deleted_at IS NULL
     AND title = '1st Quarter Exam';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'it10_friday_window: set the 1st Quarter Exam to a single attempt (% row(s))', v_n;
END $$;
