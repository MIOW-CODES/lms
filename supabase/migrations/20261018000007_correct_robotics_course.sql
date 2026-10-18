-- The existing IT10 offering is the Introduction to Robotics class. Keep its
-- roster and section timetable, rename its display title, and remove the
-- duplicate ROBOTICS offering created by the earlier catalog migration.
UPDATE public.courses
SET title = 'Introduction to Robotics', color = 'rose'
WHERE upper(replace(code, ' ', '')) = 'IT10';

DELETE FROM public.courses
WHERE upper(replace(code, ' ', '')) = 'ROBOTICS';
