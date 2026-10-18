CREATE TABLE IF NOT EXISTS public.feedback_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('bug', 'issue', 'feedback', 'course_content', 'other')),
  subject text NOT NULL CHECK (char_length(btrim(subject)) BETWEEN 1 AND 200),
  description text NOT NULL CHECK (char_length(btrim(description)) BETWEEN 1 AND 10000),
  page_url text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_review', 'resolved', 'closed')),
  admin_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_feedback_reports_reporter_created
  ON public.feedback_reports (reporter_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_reports_status_created
  ON public.feedback_reports (status, created_at DESC);

ALTER TABLE public.feedback_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY feedback_reports_deny_anon ON public.feedback_reports FOR ALL TO anon USING (false) WITH CHECK (false);
CREATE POLICY feedback_reports_deny_authenticated ON public.feedback_reports FOR ALL TO authenticated USING (false) WITH CHECK (false);
REVOKE ALL ON public.feedback_reports FROM anon, authenticated;
GRANT ALL ON public.feedback_reports TO service_role;
