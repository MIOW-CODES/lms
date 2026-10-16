-- Enroll only the verified MAED-TVLE roster in section 241.
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
    RAISE NOTICE 'ITE241 enrollment skipped: course not found';
    RETURN;
  END IF;

  INSERT INTO public.enrollments (student_id, course_id)
  SELECT p.id, v_course
    FROM public.profiles p
   WHERE p.role = 'student'
     AND p.deleted_at IS NULL
     AND p.student_id IN (
       '2013-5178','2026-3031','2014-2972','2020-4568','2014-3000','2006-6034','2013-3671',
       '2015-5283','2012-3854','2015-6672','2013-2657','2021-0762','2001-3265','2013-2885'
     )
     AND NOT EXISTS (
       SELECT 1 FROM public.enrollments e
        WHERE e.course_id = v_course AND e.student_id = p.id
     );

  GET DIAGNOSTICS v_added = ROW_COUNT;
  RAISE NOTICE 'ITE241 enrollment: added % matching MAED-TVLE students', v_added;
END $$;
