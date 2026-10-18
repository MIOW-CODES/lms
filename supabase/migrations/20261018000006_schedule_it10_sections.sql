-- Configure IT10's four Grade 10 section meeting slots.
DO $$
DECLARE
  v_course uuid;
BEGIN
  SELECT id INTO v_course
  FROM public.courses
  WHERE upper(replace(code, ' ', '')) = 'IT10'
  LIMIT 1;

  IF v_course IS NULL THEN
    RETURN;
  END IF;

  CREATE TEMP TABLE tmp_it10_members(student_id uuid PRIMARY KEY) ON COMMIT DROP;
  INSERT INTO tmp_it10_members(student_id)
  SELECT DISTINCT m.student_id
  FROM public.course_meeting_members m
  JOIN public.course_meetings cm ON cm.id = m.meeting_id
  WHERE cm.course_id = v_course
  ON CONFLICT DO NOTHING;

  DELETE FROM public.course_meetings WHERE course_id = v_course;
  INSERT INTO public.course_meetings
    (course_id, kind, label, days_of_week, start_time, end_time, capacity, sort_order)
  VALUES
    (v_course, 'lecture', '10 Tau', ARRAY['mon']::text[], '10:30', '12:10', 40, 0),
    (v_course, 'lecture', '10 Phi', ARRAY['mon']::text[], '13:00', '14:40', 40, 1),
    (v_course, 'lecture', '10 Sigma', ARRAY['fri']::text[], '10:30', '12:10', 40, 2),
    (v_course, 'lecture', '10 Omega', ARRAY['fri']::text[], '13:00', '14:40', 40, 3);

  INSERT INTO public.course_meeting_members(meeting_id, student_id)
  SELECT m.id, p.id
  FROM public.course_meetings m
  JOIN public.profiles p ON p.section = regexp_replace(m.label, '^10 ', '')
  WHERE m.course_id = v_course AND p.role = 'student'
    AND p.grade_level = 10 AND p.deleted_at IS NULL
  ON CONFLICT DO NOTHING;

  INSERT INTO public.course_meeting_members(meeting_id, student_id)
  SELECT m.id, s.student_id
  FROM public.course_meetings m
  JOIN tmp_it10_members s ON true
  JOIN public.profiles p ON p.id = s.student_id
  WHERE m.course_id = v_course
    AND p.section = regexp_replace(m.label, '^10 ', '')
  ON CONFLICT DO NOTHING;
END $$;
