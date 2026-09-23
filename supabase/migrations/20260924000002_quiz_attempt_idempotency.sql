-- Idempotent worksheet submissions.
--
-- A double-clicked submit (or a retry after a lost response) must not create a
-- duplicate attempt. Two unique indexes make the insert race-safe:
--   * (quiz_id, student_id, attempt_number) — collapses concurrent double-submits
--   * (student_id, submission_id)           — replays a retried submission
--
-- 1) Remove any pre-existing duplicate attempts, keeping the newest row per
--    group, so the unique index can be created safely on live data.
DELETE FROM public.quiz_attempts a
USING public.quiz_attempts b
WHERE a.quiz_id = b.quiz_id
  AND a.student_id = b.student_id
  AND a.attempt_number = b.attempt_number
  AND (a.created_at < b.created_at OR (a.created_at = b.created_at AND a.id < b.id));

-- 2) One row per (quiz, student, attempt_number).
CREATE UNIQUE INDEX IF NOT EXISTS quiz_attempts_unique_attempt
  ON public.quiz_attempts (quiz_id, student_id, attempt_number);

-- 3) Client-supplied idempotency key for retries.
ALTER TABLE public.quiz_attempts ADD COLUMN IF NOT EXISTS submission_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS quiz_attempts_unique_submission
  ON public.quiz_attempts (student_id, submission_id)
  WHERE submission_id IS NOT NULL;
