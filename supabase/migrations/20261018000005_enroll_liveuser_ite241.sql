-- LiveUser is the manual student test account. Keep the ITE241 course visible
-- for that account while leaving the verified Master's roster unchanged.
INSERT INTO public.enrollments (student_id, course_id)
SELECT student.id, course.id
FROM public.profiles AS student
JOIN public.courses AS course
  ON upper(replace(course.code, ' ', '')) = 'ITE241'
WHERE lower(coalesce(student.email, '')) = 'test@g.msuiit.edu.ph'
ON CONFLICT (student_id, course_id) DO NOTHING;
