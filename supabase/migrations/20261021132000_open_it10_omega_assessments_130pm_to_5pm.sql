-- Temporary section-specific assessment window for the IT10 Omega section.
-- Keep the course-level quiz window unchanged for other sections.
CREATE TABLE IF NOT EXISTS public.quiz_section_windows (
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
  section_name text NOT NULL,
  opens_at timestamptz NOT NULL,
  closes_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (quiz_id, section_name),
  CHECK (closes_at >= opens_at)
);

ALTER TABLE public.quiz_section_windows ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.quiz_section_windows FROM anon, authenticated;
GRANT ALL ON public.quiz_section_windows TO service_role;

CREATE INDEX IF NOT EXISTS quiz_section_windows_section_idx
  ON public.quiz_section_windows (lower(section_name), quiz_id);

DO $it10_omega_window$
DECLARE
  v_course_id uuid;
  v_course_count integer;
  v_omega_link_count integer;
  v_assessment_count integer;
  v_upserted integer;
BEGIN
  SELECT count(*) INTO v_course_count
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  IF v_course_count <> 1 THEN
    RAISE EXCEPTION 'IT10 Omega window stopped: expected one IT10 course, found %', v_course_count;
  END IF;

  SELECT id INTO v_course_id
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  SELECT count(*) INTO v_omega_link_count
    FROM public.course_sections cs
    JOIN public.sections s ON s.id = cs.section_id
   WHERE cs.course_id = v_course_id
     AND lower(btrim(s.name)) = 'omega';

  IF v_omega_link_count <> 1 THEN
    RAISE EXCEPTION 'IT10 Omega window stopped: expected one linked Omega section, found %', v_omega_link_count;
  END IF;

  SELECT count(*) INTO v_assessment_count
    FROM public.quizzes
   WHERE course_id = v_course_id
     AND deleted_at IS NULL;

  IF v_assessment_count = 0 THEN
    RAISE EXCEPTION 'IT10 Omega window stopped: no active quizzes or exams were found';
  END IF;

  INSERT INTO public.quiz_section_windows (quiz_id, section_name, opens_at, closes_at)
  SELECT id,
         'Omega',
         '2026-10-21T13:30:00+08:00'::timestamptz,
         '2026-10-21T17:00:00+08:00'::timestamptz
    FROM public.quizzes
   WHERE course_id = v_course_id
     AND deleted_at IS NULL
  ON CONFLICT (quiz_id, section_name) DO UPDATE
    SET opens_at = EXCLUDED.opens_at,
        closes_at = EXCLUDED.closes_at;

  GET DIAGNOSTICS v_upserted = ROW_COUNT;
  RAISE NOTICE 'Opened % active IT10 assessments for Omega from 1:30 PM to 5 PM Asia/Manila on 2026-10-21', v_upserted;
END;
$it10_omega_window$;
