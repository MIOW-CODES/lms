-- Normalize PRELIM EXAMINATION to serve its full 100-item bank.
--
-- The TVE100 clone shipped question_count = 80 (80 sampled of a 100-item bank
-- per attempt). The approved spec for the exam rebuild is "100Q / 60min" — the
-- same as FINAL EXAMINATION — so serve all 100 items. Duration (60) and all
-- availability/release state are left untouched. Teacher can flip the
-- per-attempt sample back in the worksheet Edit dialog if the 80-sampling
-- behavior is preferred.
--
-- Idempotent: single targeted UPDATE; re-running is a no-op.
DO $$
DECLARE
  v_n int;
BEGIN
  UPDATE public.quizzes
     SET question_count = 100
   WHERE title = 'PRELIM EXAMINATION (Coverage: Weeks 1-7)'
     AND deleted_at IS NULL
     AND question_count IS DISTINCT FROM 100;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'ict1_prelim_full_bank: updated % PRELIM row(s) to question_count=100', v_n;
END $$;
