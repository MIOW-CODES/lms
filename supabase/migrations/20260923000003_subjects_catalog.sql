-- MIOW-LMS: Subject catalog + college sections
-- Provides a first-class subject database (distinct from course offerings) and
-- named sections for college programs. Course offerings may reference a subject.

-- 1. Subject catalog
CREATE TABLE IF NOT EXISTS public.subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  units numeric,
  lecture_hours numeric,
  lab_hours numeric,
  description text,
  prerequisites text,
  education_level text CHECK (education_level IN ('jhs','shs','college')) DEFAULT 'college',
  program text,
  college_year int CHECK (college_year BETWEEN 1 AND 4),
  term text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS subjects_code_idx ON public.subjects (code);
CREATE INDEX IF NOT EXISTS subjects_program_idx ON public.subjects (program);

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public demo access" ON public.subjects;
CREATE POLICY "Public demo access" ON public.subjects
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- 2. College / school sections (named cohorts)
CREATE TABLE IF NOT EXISTS public.sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  education_level text CHECK (education_level IN ('jhs','shs','college')) DEFAULT 'college',
  program text,
  college_year int CHECK (college_year BETWEEN 1 AND 4),
  adviser_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (name, program, college_year)
);

CREATE INDEX IF NOT EXISTS sections_program_idx ON public.sections (program);

ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public demo access" ON public.sections;
CREATE POLICY "Public demo access" ON public.sections
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- 3. Optional link from a course offering to its catalog subject
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL;
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS section_id uuid REFERENCES public.sections(id) ON DELETE SET NULL;

-- 4. Seed the TVE100 catalog subject (matches the seeded course offering)
INSERT INTO public.subjects (code, title, units, lecture_hours, education_level, program, college_year, term)
VALUES (
  'TVE100',
  'The Teacher and the Community, School Culture & Organizational Leadership',
  3,
  3,
  'college',
  'BTVTED-DT',
  2,
  '1st Semester'
) ON CONFLICT (code) DO NOTHING;

-- 5. Seed common college sections referenced by the imported class list
INSERT INTO public.sections (name, education_level, program, college_year)
VALUES
  ('B8', 'college', 'BTVTED-DT', 2),
  ('B8', 'college', 'BTVTED-DT', 3),
  ('B8', 'college', 'BTVTED-DT', 4)
ON CONFLICT (name, program, college_year) DO NOTHING;
