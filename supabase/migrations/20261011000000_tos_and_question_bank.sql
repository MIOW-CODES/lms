-- =============================================================================
-- MIOW-LMS: Table of Specifications (TOS) + question bank view
-- =============================================================================
-- 1. public.tos — one Table of Specifications per (course, quarter); items is a
--    jsonb array of {topic, no_of_items, cognitive_level, quiz_id, note}.
-- 2. public.question_bank — SECURITY INVOKER view joining quiz_questions →
--    quizzes → courses so the staff question bank has course context in one
--    query.
-- 3. Seed: IT10 TOS rows for the quarters that have quizzes, with per-quiz
--    question counts as coarse topics (cognitive_level defaults to
--    'understanding' — teachers refine it in the TOS editor).
-- Idempotent: safe to run any number of times.
-- =============================================================================

-- ── 0. quiz_questions.created_at (the question bank view exposes it) ────────
ALTER TABLE public.quiz_questions
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- ── 1. Table of Specifications ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  quarter int NOT NULL CHECK (quarter BETWEEN 1 AND 8),
  title text,
  items jsonb NOT NULL DEFAULT '[]',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, quarter)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.tos TO anon, authenticated;
GRANT ALL ON public.tos TO service_role;
ALTER TABLE public.tos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public full access tos" ON public.tos;
CREATE POLICY "public full access tos" ON public.tos
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ── 2. Question bank view (SECURITY INVOKER — uses the caller's RLS) ────────
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
  qq.created_at
FROM public.quiz_questions qq
JOIN public.quizzes q ON q.id = qq.quiz_id
JOIN public.courses c ON c.id = q.course_id;

GRANT SELECT ON public.question_bank TO anon, authenticated, service_role;

-- ── 3. Seed IT10 TOS rows (quarters 1–2) ────────────────────────────────────
-- Coarse topics come straight from the quiz titles; no_of_items is the live
-- question count of each quiz. One TOS row per quarter that has quizzes,
-- guarded so re-runs never duplicate.
DO $$
DECLARE
  v_course uuid;
  v_q int;
  v_items jsonb;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'IT10';
  IF v_course IS NULL THEN
    RAISE NOTICE '[tos] IT10 course not found — skipping TOS seed';
    RETURN;
  END IF;

  FOR v_q IN SELECT 1 UNION ALL SELECT 2 LOOP
    -- Idempotent: a quarter that already has a TOS row is left untouched.
    IF EXISTS (
      SELECT 1 FROM public.tos WHERE course_id = v_course AND quarter = v_q
    ) THEN
      CONTINUE;
    END IF;

    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'topic', m.topic,
          'no_of_items', cnt.n,
          'cognitive_level', 'understanding',
          'quiz_id', cnt.quiz_id,
          'note', NULL
        )
        ORDER BY m.ord
      ),
      '[]'::jsonb
    )
    INTO v_items
    FROM (
      VALUES
        (1, 1, 'Quiz — Arduino Part 1', 'Arduino Part 1'),
        (2, 1, 'Quiz — Lab Activity 1 (Blinking LED)', 'Lab Activity 1 (Blinking LED)'),
        (3, 1, 'Quiz — Resistor Color Code', 'Resistor Color Code'),
        (4, 1, 'Quiz — Programming with Arduino', 'Programming with Arduino'),
        (5, 1, '1st Quarter Exam', '1st Quarter Exam'),
        (6, 2, 'Quiz — Arduino Part 2', 'Arduino Part 2')
    ) AS m(ord, quarter, quiz_title, topic)
    CROSS JOIN LATERAL (
      SELECT
        count(qq.id) AS n,
        (array_agg(q.id ORDER BY q.created_at DESC, q.id DESC))[1] AS quiz_id
      FROM public.quizzes q
      LEFT JOIN public.quiz_questions qq ON qq.quiz_id = q.id
      WHERE q.course_id = v_course
        AND q.title = m.quiz_title
        AND q.deleted_at IS NULL
    ) cnt
    WHERE m.quarter = v_q
      AND cnt.n > 0;

    -- Only seed quarters that actually have quizzes.
    IF v_items IS NULL OR v_items = '[]'::jsonb THEN
      CONTINUE;
    END IF;

    INSERT INTO public.tos (course_id, quarter, title, items)
    VALUES (
      v_course,
      v_q,
      format('Quarter %s — Table of Specifications', v_q),
      v_items
    );
  END LOOP;
END $$;
