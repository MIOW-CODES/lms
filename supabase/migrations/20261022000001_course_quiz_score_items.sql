-- Editable quiz score columns used alongside automatic worksheet scores.
CREATE TABLE IF NOT EXISTS public.course_quiz_score_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  title text NOT NULL,
  sort_order integer NOT NULL DEFAULT 1 CHECK (sort_order > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, title)
);

CREATE TABLE IF NOT EXISTS public.course_quiz_scores (
  item_id uuid NOT NULL REFERENCES public.course_quiz_score_items(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score numeric NOT NULL CHECK (score >= 0),
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (item_id, student_id)
);

CREATE INDEX IF NOT EXISTS course_quiz_score_items_course_order_idx
  ON public.course_quiz_score_items (course_id, sort_order, created_at);
CREATE INDEX IF NOT EXISTS course_quiz_scores_student_idx
  ON public.course_quiz_scores (student_id);

GRANT ALL ON public.course_quiz_score_items TO service_role;
GRANT ALL ON public.course_quiz_scores TO service_role;
REVOKE ALL ON public.course_quiz_score_items FROM anon, authenticated;
REVOKE ALL ON public.course_quiz_scores FROM anon, authenticated;

ALTER TABLE public.course_quiz_score_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_quiz_scores ENABLE ROW LEVEL SECURITY;

-- No anon/authenticated policies: direct client access is denied. Server calls
-- use the service role after checking staff/course ownership in application code.
DROP POLICY IF EXISTS "Public demo access" ON public.course_quiz_score_items;
DROP POLICY IF EXISTS "Public demo access" ON public.course_quiz_scores;

COMMENT ON TABLE public.course_quiz_score_items IS
  'Staff-managed quiz score columns attached to a course, separate from student-facing worksheets.';
COMMENT ON TABLE public.course_quiz_scores IS
  'Student scores entered for staff-managed course quiz score columns.';

-- Reserve Quiz 4 for the all-sections IT10 score sheet.
INSERT INTO public.course_quiz_score_items (course_id, title, sort_order)
SELECT id, 'Quiz 4', 4
FROM public.courses
WHERE upper(btrim(code)) = 'IT10'
ON CONFLICT (course_id, title) DO NOTHING;
