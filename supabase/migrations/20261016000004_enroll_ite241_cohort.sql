-- Enroll the ITE241 Advanced Digital Electronics cohort.
-- Cohort rule follows the other College Year 2 electronics course: year 2 and
-- electronics program/section, with a grade-level fallback for roster imports.
DO $$
DECLARE
  v_course uuid;
  v_added integer := 0;
BEGIN
  SELECT id INTO v_course
    FROM public.courses
   WHERE upper(replace(code, ' ', '')) = 'ITE241'
      OR upper(regexp_replace(title, '[^a-zA-Z0-9]', '', 'g')) = 'ITE241ADVANCEDDIGITALELECTRONICS'
   ORDER BY (upper(replace(code, ' ', '')) = 'ITE241') DESC
   LIMIT 1;

  IF v_course IS NULL THEN
    RAISE EXCEPTION 'ITE241 enrollment failed: course not found';
  END IF;

  INSERT INTO public.enrollments (student_id, course_id)
  SELECT p.id, v_course
    FROM public.profiles p
   WHERE p.role = 'student'
     AND p.deleted_at IS NULL
     AND (
       p.grade_level = 14
       OR coalesce(p.section, '') ILIKE '%electronics%'
       OR coalesce(p.section, '') ILIKE 'BTLED%'
       OR coalesce(p.section, '') ILIKE 'BTVTED%'
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.enrollments e
        WHERE e.course_id = v_course AND e.student_id = p.id
     );

  GET DIAGNOSTICS v_added = ROW_COUNT;
  RAISE NOTICE 'ITE241 enrollment: added % matching second-year/electronics students', v_added;
END $$;
