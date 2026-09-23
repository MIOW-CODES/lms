-- Performance indexes for the question-bank lookups.
-- getQuizPublic() fetches a student's prior attempts (quiz_id + student_id) on
-- every worksheet open, and listMyQuizSummaries() scans by student_id. Neither
-- was indexed, so both caused sequential scans as attempt history grew.

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz_student
  ON public.quiz_attempts(quiz_id, student_id);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_student_id
  ON public.quiz_attempts(student_id);
