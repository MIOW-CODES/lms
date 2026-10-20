-- Open the existing IT10 assessment set for Tau through 6 PM Asia/Manila.
-- Sigma's section-specific window is unchanged.
DO $it10_tau_window$
DECLARE
  v_course_id uuid;
  v_course_count integer;
  v_tau_link_count integer;
  v_assessment_count integer;
  v_upserted integer;
BEGIN
  SELECT count(*) INTO v_course_count
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  IF v_course_count <> 1 THEN
    RAISE EXCEPTION 'IT10 Tau window stopped: expected one IT10 course, found %', v_course_count;
  END IF;

  SELECT id INTO v_course_id
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'IT10';

  SELECT count(*) INTO v_tau_link_count
    FROM public.course_sections cs
    JOIN public.sections s ON s.id = cs.section_id
   WHERE cs.course_id = v_course_id
     AND lower(btrim(s.name)) = 'tau';

  IF v_tau_link_count <> 1 THEN
    RAISE EXCEPTION 'IT10 Tau window stopped: expected one linked Tau section, found %', v_tau_link_count;
  END IF;

  SELECT count(*) INTO v_assessment_count
    FROM public.quizzes
   WHERE course_id = v_course_id
     AND deleted_at IS NULL;

  IF v_assessment_count = 0 THEN
    RAISE EXCEPTION 'IT10 Tau window stopped: no active quizzes or exams were found';
  END IF;

  INSERT INTO public.quiz_section_windows (quiz_id, section_name, opens_at, closes_at)
  SELECT id,
         'Tau',
         '2026-10-20T13:00:00+08:00'::timestamptz,
         '2026-10-20T18:00:00+08:00'::timestamptz
    FROM public.quizzes
   WHERE course_id = v_course_id
     AND deleted_at IS NULL
  ON CONFLICT (quiz_id, section_name) DO UPDATE
    SET opens_at = EXCLUDED.opens_at,
        closes_at = EXCLUDED.closes_at;

  GET DIAGNOSTICS v_upserted = ROW_COUNT;
  RAISE NOTICE 'Opened % active IT10 assessments for Tau from 1 PM to 6 PM Asia/Manila on 2026-10-20', v_upserted;
END;
$it10_tau_window$;
