-- =============================================================================
-- MIOW-LMS: Grade column overrides + course meetings (ICT1) + course sections
-- =============================================================================
-- 1. grades.override_flags      — per-cell (WW / PT / Exam) teacher override state
-- 2. course_meetings            — Lecture/Lab slots per course (ICT1: 1 lecture + 2 labs)
-- 3. course_meeting_members     — which students attend which meeting slot
-- 4. course_sections            — link a course offering to named sections (IT10 ×
--                                  Omega/Phi/Sigma/Tau)
-- 5. Seed the four Grade 10 sections (idempotent)
-- All statements are idempotent (IF NOT EXISTS / guarded inserts).
-- =============================================================================

-- ── 1. Per-cell override flags on the gradebook row ──────────────────────────
-- Shape: { "ww": {"note": "...", "by": "<uuid>", "at": "<iso>" },
--          "pt": {...}, "ex": {...} }   — presence of a key = cell is overridden.
ALTER TABLE public.grades
  ADD COLUMN IF NOT EXISTS override_flags jsonb NOT NULL DEFAULT '{}'::jsonb;

-- ── 2. Course meetings (weekly timetable slots) ──────────────────────────────
CREATE TABLE IF NOT EXISTS public.course_meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('lecture', 'lab')),
  label text NOT NULL,
  days_of_week text[] NOT NULL DEFAULT '{}',
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  capacity int CHECK (capacity IS NULL OR capacity > 0),
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS course_meetings_course_idx
  ON public.course_meetings (course_id, sort_order);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.course_meetings TO anon, authenticated;
GRANT ALL ON public.course_meetings TO service_role;
ALTER TABLE public.course_meetings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public demo access" ON public.course_meetings;
CREATE POLICY "Public demo access" ON public.course_meetings
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ── 3. Meeting membership (a student attends the lecture + exactly one lab) ──
CREATE TABLE IF NOT EXISTS public.course_meeting_members (
  meeting_id uuid NOT NULL REFERENCES public.course_meetings(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (meeting_id, student_id)
);

CREATE INDEX IF NOT EXISTS course_meeting_members_student_idx
  ON public.course_meeting_members (student_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.course_meeting_members TO anon, authenticated;
GRANT ALL ON public.course_meeting_members TO service_role;
ALTER TABLE public.course_meeting_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public demo access" ON public.course_meeting_members;
CREATE POLICY "Public demo access" ON public.course_meeting_members
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ── 4. Course ↔ section links ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.course_sections (
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  section_id uuid NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (course_id, section_id)
);

CREATE INDEX IF NOT EXISTS course_sections_section_idx
  ON public.course_sections (section_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.course_sections TO anon, authenticated;
GRANT ALL ON public.course_sections TO service_role;
ALTER TABLE public.course_sections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public demo access" ON public.course_sections;
CREATE POLICY "Public demo access" ON public.course_sections
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ── 5. Seed Grade 10 sections (Omega / Phi / Sigma / Tau) ────────────────────
-- NOTE: sections has UNIQUE(name, program, college_year); program/college_year
-- are NULL for JHS sections and NULLs never collide in Postgres, so a plain
-- ON CONFLICT would not protect against duplicates. Guard with NOT EXISTS.
DO $$
DECLARE
  sec text;
BEGIN
  FOREACH sec IN ARRAY ARRAY['Omega', 'Phi', 'Sigma', 'Tau'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.sections
      WHERE name = sec AND education_level = 'jhs'
    ) THEN
      INSERT INTO public.sections (name, education_level)
      VALUES (sec, 'jhs');
    END IF;
  END LOOP;
END $$;

-- Link IT10 to all four Grade 10 sections once both sides exist.
INSERT INTO public.course_sections (course_id, section_id)
SELECT c.id, s.id
FROM public.courses c
JOIN public.sections s
  ON s.education_level = 'jhs' AND s.name IN ('Omega', 'Phi', 'Sigma', 'Tau')
WHERE c.code = 'IT10'
ON CONFLICT DO NOTHING;
