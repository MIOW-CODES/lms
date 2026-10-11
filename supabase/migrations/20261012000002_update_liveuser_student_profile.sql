-- Update LiveUser (test@g.msuiit.edu.ph) profile fields for student view manual checks.
-- Sets grade_level = 10, section = 'Einstein', student_id = 'LIVE-TEST-01'.

UPDATE public.profiles
   SET grade_level = 10,
       section = 'Einstein',
       student_id = COALESCE(student_id, 'LIVE-TEST-01')
 WHERE lower(coalesce(email, '')) = 'test@g.msuiit.edu.ph';
