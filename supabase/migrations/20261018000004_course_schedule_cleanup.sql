-- Current course timetable and catalog cleanup.
-- ICT1 is intentionally removed in full; dependent content, enrollments, and
-- meeting memberships follow the course through their cascade constraints.
DO $$
DECLARE
  v_teacher uuid;
  v_iae uuid;
  v_tve uuid;
  v_ite uuid;
  v_robotics uuid;
BEGIN
  CREATE TEMP TABLE tmp_schedule_members(course_id uuid NOT NULL, student_id uuid NOT NULL,
    PRIMARY KEY (course_id, student_id)) ON COMMIT DROP;
  SELECT id INTO v_teacher
  FROM public.profiles
  WHERE lower(email) = 'alan.vergara@g.msuiit.edu.ph'
    AND deleted_at IS NULL
  LIMIT 1;

  -- Remove the ICT1 lab offering completely (the course code identifies the
  -- offering even when older rows used an "ICT1 - LAB" title).
  DELETE FROM public.courses
  WHERE upper(replace(code, ' ', '')) = 'ICT1'
     OR upper(title) LIKE '%ICT1%LAB%';

  SELECT id INTO v_iae FROM public.courses WHERE upper(replace(code, ' ', '')) = 'IAE106' LIMIT 1;
  SELECT id INTO v_tve FROM public.courses WHERE upper(replace(code, ' ', '')) = 'TVE100' LIMIT 1;
  SELECT id INTO v_ite FROM public.courses WHERE upper(replace(code, ' ', '')) = 'ITE241' LIMIT 1;
  INSERT INTO tmp_schedule_members(course_id, student_id)
  SELECT cm.course_id, m.student_id
  FROM public.course_meeting_members m
  JOIN public.course_meetings cm ON cm.id = m.meeting_id
  WHERE cm.course_id IN (v_iae, v_tve, v_ite)
  ON CONFLICT DO NOTHING;
  IF v_iae IS NOT NULL THEN
    UPDATE public.courses
       SET title = 'Fundamentals of Electronics Technology',
           days_of_week = ARRAY['fri']::text[], start_time = '15:00:00', end_time = '17:00:00',
           teacher_id = COALESCE(v_teacher, teacher_id)
     WHERE id = v_iae;
    DELETE FROM public.course_meetings WHERE course_id = v_iae;
    INSERT INTO public.course_meetings(course_id, kind, label, days_of_week, start_time, end_time, sort_order)
    VALUES (v_iae, 'lecture', 'Friday class', ARRAY['fri']::text[], '15:00', '17:00', 0);
    INSERT INTO public.course_meeting_members(meeting_id, student_id)
    SELECT cm.id, sm.student_id FROM public.course_meetings cm
    JOIN tmp_schedule_members sm ON sm.course_id = v_iae
    WHERE cm.course_id = v_iae ON CONFLICT DO NOTHING;
  END IF;

  IF v_tve IS NOT NULL THEN
    UPDATE public.courses
       SET days_of_week = ARRAY['tue','thu']::text[], start_time = '18:00:00', end_time = '19:30:00',
           teacher_id = COALESCE(v_teacher, teacher_id)
     WHERE id = v_tve;
    DELETE FROM public.course_meetings WHERE course_id = v_tve;
    INSERT INTO public.course_meetings(course_id, kind, label, days_of_week, start_time, end_time, sort_order)
    VALUES (v_tve, 'lecture', 'Tuesday / Thursday class', ARRAY['tue','thu']::text[], '18:00', '19:30', 0);
    INSERT INTO public.course_meeting_members(meeting_id, student_id)
    SELECT cm.id, sm.student_id FROM public.course_meetings cm
    JOIN tmp_schedule_members sm ON sm.course_id = v_tve
    WHERE cm.course_id = v_tve ON CONFLICT DO NOTHING;
  END IF;

  IF v_ite IS NOT NULL THEN
    UPDATE public.courses
       SET days_of_week = ARRAY['sat']::text[], start_time = '08:00:00', end_time = '12:00:00',
           teacher_id = COALESCE(v_teacher, teacher_id)
     WHERE id = v_ite;
    DELETE FROM public.course_meetings WHERE course_id = v_ite;
    INSERT INTO public.course_meetings(course_id, kind, label, days_of_week, start_time, end_time, sort_order)
    VALUES (v_ite, 'lecture', 'Saturday class', ARRAY['sat']::text[], '08:00', '12:00', 0);
    INSERT INTO public.course_meeting_members(meeting_id, student_id)
    SELECT cm.id, sm.student_id FROM public.course_meetings cm
    JOIN tmp_schedule_members sm ON sm.course_id = v_ite
    WHERE cm.course_id = v_ite ON CONFLICT DO NOTHING;
  END IF;

  -- Robotics is a new Grade 10 offering with four section-specific meeting
  -- slots. Existing section and enrollment rows are reused when present.
  INSERT INTO public.courses AS target_course(title, code, grade_level, color, education_level, grading_system, teacher_id)
  VALUES ('Introduction to Robotics', 'ROBOTICS', 10, 'rose', 'jhs', 'k12_quarterly', v_teacher)
  ON CONFLICT (code) DO UPDATE SET
    title = EXCLUDED.title, grade_level = EXCLUDED.grade_level,
    education_level = EXCLUDED.education_level, grading_system = EXCLUDED.grading_system,
    teacher_id = COALESCE(EXCLUDED.teacher_id, target_course.teacher_id)
  RETURNING id INTO v_robotics;

  IF v_robotics IS NULL THEN
    SELECT id INTO v_robotics FROM public.courses WHERE code = 'ROBOTICS' LIMIT 1;
  END IF;

  INSERT INTO tmp_schedule_members(course_id, student_id)
  SELECT cm.course_id, m.student_id
  FROM public.course_meeting_members m
  JOIN public.course_meetings cm ON cm.id = m.meeting_id
  WHERE cm.course_id = v_robotics
  ON CONFLICT DO NOTHING;
  DELETE FROM public.course_meetings WHERE course_id = v_robotics;
  INSERT INTO public.course_meetings(course_id, kind, label, days_of_week, start_time, end_time, capacity, sort_order)
  VALUES
    (v_robotics, 'lecture', '10 Tau', ARRAY['mon']::text[], '10:30', '12:10', 40, 0),
    (v_robotics, 'lecture', '10 Phi', ARRAY['mon']::text[], '13:00', '14:40', 40, 1),
    (v_robotics, 'lecture', '10 Sigma', ARRAY['fri']::text[], '10:30', '12:10', 40, 2),
    (v_robotics, 'lecture', '10 Omega', ARRAY['fri']::text[], '13:00', '14:40', 40, 3);

  INSERT INTO public.course_sections(course_id, section_id)
  SELECT v_robotics, s.id FROM public.sections s
  WHERE s.name IN ('Tau', 'Phi', 'Sigma', 'Omega')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.enrollments(student_id, course_id)
  SELECT p.id, v_robotics FROM public.profiles p
  WHERE p.role = 'student' AND p.grade_level = 10 AND p.deleted_at IS NULL
    AND p.section IN ('Tau', 'Phi', 'Sigma', 'Omega')
  ON CONFLICT (student_id, course_id) DO NOTHING;

  INSERT INTO public.course_meeting_members(meeting_id, student_id)
  SELECT m.id, p.id
  FROM public.course_meetings m
  JOIN public.profiles p ON p.section = regexp_replace(m.label, '^10 ', '')
  WHERE m.course_id = v_robotics AND p.role = 'student' AND p.grade_level = 10 AND p.deleted_at IS NULL
  ON CONFLICT DO NOTHING;

  INSERT INTO public.course_meeting_members(meeting_id, student_id)
  SELECT m.id, sm.student_id
  FROM public.course_meetings m
  JOIN tmp_schedule_members sm ON sm.course_id = v_robotics
  JOIN public.profiles p ON p.id = sm.student_id
  WHERE m.course_id = v_robotics
    AND p.section = regexp_replace(m.label, '^10 ', '')
  ON CONFLICT DO NOTHING;
END $$;
