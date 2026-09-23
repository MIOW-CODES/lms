-- MIOW-LMS: Teacher score overrides for worksheet attempts
-- The AI ("ClassMate Assistant") can mis-grade. A teacher may override a
-- student's effective worksheet score without destroying the AI attempt record.
-- One override row per (quiz, student); the raw attempts stay intact.

CREATE TABLE IF NOT EXISTS public.quiz_score_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score numeric,
  total numeric,
  notes text,
  overridden_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (quiz_id, student_id)
);

CREATE INDEX IF NOT EXISTS quiz_score_overrides_quiz_idx ON public.quiz_score_overrides (quiz_id);

ALTER TABLE public.quiz_score_overrides ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public demo access" ON public.quiz_score_overrides;
CREATE POLICY "Public demo access" ON public.quiz_score_overrides
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

COMMENT ON TABLE public.quiz_score_overrides IS
  'Teacher manual override of a student''s effective worksheet score; AI attempts preserved.';
