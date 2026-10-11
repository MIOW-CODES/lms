-- =============================================================================
-- MIOW-LMS: Session-scoped test role view + richer question_bank rows
-- =============================================================================
-- 1. sessions.role_view — the portal view ('teacher' | 'admin' | 'student')
--    chosen by the allowlisted demo Test Account (test@g.msuiit.edu.ph).
--    NULL = the account's real role (default on every fresh login). The column
--    is ONLY ever honored for that one email in the session read path
--    (auth.server requireSession → applyRoleView); the real profiles.role is
--    never changed. RLS on sessions already denies everything but service_role.
-- 2. public.question_bank gains quiz_title / quiz_created_at / quiz_deleted_at
--    so the staff question bank can surface every worksheet of a course
--    (including archived ones) with a stable worksheet order and per-worksheet
--    counts — no second lookup against the live quizzes list required.
-- Idempotent: safe to run any number of times.
-- =============================================================================

-- ── 1. Session-scoped role view ─────────────────────────────────────────────
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS role_view text;

ALTER TABLE public.sessions
  DROP CONSTRAINT IF EXISTS sessions_role_view_check;
ALTER TABLE public.sessions
  ADD CONSTRAINT sessions_role_view_check
  CHECK (role_view IS NULL OR role_view IN ('teacher', 'admin', 'student'));

-- ── 2. Question bank view: worksheet context columns ────────────────────────
-- Column order is append-only so CREATE OR REPLACE stays valid on existing DBs.
CREATE OR REPLACE VIEW public.question_bank
WITH (security_invoker = true) AS
SELECT
  qq.id,
  qq.quiz_id,
  q.course_id,
  c.code AS course_code,
  qq.question,
  qq.options,
  qq.correct_answer,
  qq.position,
  qq.image_url,
  qq.lab_task,
  qq.required,
  qq.created_at,
  q.title AS quiz_title,
  q.created_at AS quiz_created_at,
  q.deleted_at AS quiz_deleted_at
FROM public.quiz_questions qq
JOIN public.quizzes q ON q.id = qq.quiz_id
JOIN public.courses c ON c.id = q.course_id;

GRANT SELECT ON public.question_bank TO anon, authenticated, service_role;

-- ── 3. Visibility for `supabase db push` output ─────────────────────────────
DO $$
DECLARE
  has_col int;
  cols int;
BEGIN
  SELECT count(*) INTO has_col
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'sessions' AND column_name = 'role_view';
  SELECT count(*) INTO cols
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'question_bank';
  RAISE NOTICE 'role view + question bank cols: sessions.role_view present = %, question_bank columns = %',
               has_col, cols;
END $$;
