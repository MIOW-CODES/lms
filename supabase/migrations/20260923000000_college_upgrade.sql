-- MIOW-LMS College Upgrade Migration
-- Expands schema for college support, multi-file uploads, grade overrides, and subject seeding

-- 1. Expand grades.quarter constraint from 1-4 to 1-8
-- (College: 1=Prelim, 2=Midterm, 3=Semi-Final, 4=Final per semester; or reuse 1-4 per sem)
ALTER TABLE public.grades DROP CONSTRAINT IF EXISTS grades_quarter_check;
ALTER TABLE public.grades ADD CONSTRAINT grades_quarter_check CHECK (quarter BETWEEN 1 AND 8);

-- 2. Add multi-file support to submissions (keep file_url for backward compat)
ALTER TABLE public.submissions ADD COLUMN IF NOT EXISTS file_urls jsonb DEFAULT '[]'::jsonb;
-- Backfill existing single file_url into file_urls array
UPDATE public.submissions 
SET file_urls = jsonb_build_array(jsonb_build_object('url', file_url, 'name', file_url, 'size', 0, 'type', 'application/octet-stream'))
WHERE file_url IS NOT NULL AND file_url != '' AND (file_urls IS NULL OR file_urls = '[]'::jsonb);

-- 3. Grade override fields (for both grades and quiz attempts)
ALTER TABLE public.grades ADD COLUMN IF NOT EXISTS overridden_by_teacher boolean DEFAULT false;
ALTER TABLE public.grades ADD COLUMN IF NOT EXISTS override_notes text;
ALTER TABLE public.grades ADD COLUMN IF NOT EXISTS overridden_at timestamptz;
ALTER TABLE public.grades ADD COLUMN IF NOT EXISTS overridden_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 4. Add grading_system column to courses for college vs K-12
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS grading_system text CHECK (grading_system IN ('k12_quarterly', 'college_semestral')) DEFAULT 'k12_quarterly';
-- Backfill: college courses get semestral
UPDATE public.courses SET grading_system = 'college_semestral' WHERE education_level = 'college' AND (grading_system IS NULL OR grading_system = 'k12_quarterly');

-- 5. Seed TVE100 subject as a course
INSERT INTO public.courses (id, title, code, grade_level, education_level, college_year, program, color, grading_system)
VALUES (
  gen_random_uuid(),
  'The Teacher and the Community, School Culture & Organizational Leadership',
  'TVE100',
  14,  -- 2nd year = grade_level 14
  'college',
  2,
  'BTVTED-DT',
  'violet',
  'college_semestral'
) ON CONFLICT (code) DO NOTHING;
