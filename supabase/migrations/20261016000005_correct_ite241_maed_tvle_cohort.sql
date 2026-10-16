-- Correct the ITE241 course to its verified Master's roster (section 241).
-- Student IDs, names, and year levels come from the user-provided class list.
-- Student PINs follow the existing roster-import convention and are forced to
-- change on first login; existing credentials are preserved on re-runs.
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION private.miow_slug(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(
    translate(
      lower(coalesce(input, '')),
      'áàâäãåéèêëíìîïóòôöõúùûüñçýÿÁÀÂÄÃÅÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÜÑÇÝ',
      'aaaaaaeeeeiiiiooooouuuuncyyAAAAAAEEEEIIIIOOOOOUUUUNCY'
    ),
    '[^a-z0-9]',
    '',
    'g'
  );
$$;

DO $$
DECLARE
  v_course uuid;
  v_section uuid;
  v_expected integer := 14;
  v_found integer := 0;
BEGIN
  SELECT id INTO v_course
    FROM public.courses
   WHERE upper(replace(code, ' ', '')) = 'ITE241'
      OR upper(regexp_replace(title, '[^a-zA-Z0-9]', '', 'g')) = 'ITE241ADVANCEDDIGITALELECTRONICS'
   ORDER BY (upper(replace(code, ' ', '')) = 'ITE241') DESC
   LIMIT 1;

  IF v_course IS NULL THEN
    RAISE NOTICE 'ITE241 Master roster correction skipped: course not found';
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.sections
     WHERE name = '241'
       AND program = 'Master of Arts in Education major in Technology and Vocational-Livelihood Education (MAED-TVLE)'
  ) THEN
    INSERT INTO public.sections (name, education_level, program, college_year)
    VALUES (
      '241',
      'college',
      'Master of Arts in Education major in Technology and Vocational-Livelihood Education (MAED-TVLE)',
      NULL
    );
  END IF;

  SELECT id INTO v_section
    FROM public.sections
   WHERE name = '241'
     AND program = 'Master of Arts in Education major in Technology and Vocational-Livelihood Education (MAED-TVLE)'
   ORDER BY created_at
   LIMIT 1;

  UPDATE public.courses
     SET program = 'Master of Arts in Education major in Technology and Vocational-Livelihood Education (MAED-TVLE)',
         education_level = 'college',
         college_year = NULL,
         section_id = v_section
   WHERE id = v_course;

  INSERT INTO public.course_sections (course_id, section_id)
  VALUES (v_course, v_section)
  ON CONFLICT (course_id, section_id) DO NOTHING;

  WITH roster(student_id, full_name, year_level) AS (
    VALUES
      ('2013-5178', 'BUCOL, EMMAREH S.', 2),
      ('2026-3031', 'CASIM, ASNOR A.', 1),
      ('2014-2972', 'DENILA, JEFFREY C.', 1),
      ('2020-4568', 'ELAGO, GOLDEN MARK R.', 1),
      ('2014-3000', 'LAPAD, SHELLO A.', 1),
      ('2006-6034', 'MAYOL, JANIZA C.', 2),
      ('2013-3671', 'RANGAIG, ANIA H.', 1),
      ('2015-5283', 'SASIL, MARIEL GRACE M.', 1),
      ('2012-3854', 'SUMINO, FE C.', 1),
      ('2015-6672', 'TEE, KRISCIA CRISALLE R.', 1),
      ('2013-2657', 'TINGCANG, PRINCESS C.', 2),
      ('2021-0762', 'TUBAL, JEYPRIL A.', 1),
      ('2001-3265', 'TUNDAG, KATHY LYN C.', 1),
      ('2013-2885', 'YAÑEZ, MARIEL L.', 2)
  )
  INSERT INTO public.profiles (
    student_id, email, pin, pin_hash, full_name, role, grade_level, section, pin_must_change
  )
  SELECT
    r.student_id,
    private.miow_slug(
      regexp_replace(trim(substring(r.full_name from position(',' in r.full_name) + 1)), '\s+[A-Za-z]\.?\s*$', '')
    ) || '.' || private.miow_slug(trim(split_part(r.full_name, ',', 1))) || '@g.msuiit.edu.ph',
    r.student_id,
    extensions.crypt(r.student_id, extensions.gen_salt('bf', 10)),
    r.full_name,
    'student'::public.profile_role,
    12 + r.year_level,
    '241',
    true
  FROM roster r
  ON CONFLICT (student_id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    grade_level = EXCLUDED.grade_level,
    section = EXCLUDED.section,
    deleted_at = NULL,
    email = COALESCE(public.profiles.email, EXCLUDED.email)
  WHERE public.profiles.role = 'student';

  SELECT count(*) INTO v_found
    FROM public.profiles p
   WHERE p.role = 'student'
     AND p.deleted_at IS NULL
     AND p.student_id IN (
       '2013-5178','2026-3031','2014-2972','2020-4568','2014-3000','2006-6034','2013-3671',
       '2015-5283','2012-3854','2015-6672','2013-2657','2021-0762','2001-3265','2013-2885'
     );

  IF v_found <> v_expected THEN
    RAISE EXCEPTION 'ITE241 roster correction expected % student accounts, found %', v_expected, v_found;
  END IF;

  DELETE FROM public.enrollments
   WHERE course_id = v_course
     AND student_id NOT IN (
       SELECT id FROM public.profiles
        WHERE role = 'student'
          AND deleted_at IS NULL
          AND student_id IN (
            '2013-5178','2026-3031','2014-2972','2020-4568','2014-3000','2006-6034','2013-3671',
            '2015-5283','2012-3854','2015-6672','2013-2657','2021-0762','2001-3265','2013-2885'
          )
     );

  INSERT INTO public.enrollments (student_id, course_id)
  SELECT p.id, v_course
    FROM public.profiles p
   WHERE p.role = 'student'
     AND p.deleted_at IS NULL
     AND p.section = '241'
     AND p.student_id IN (
       '2013-5178','2026-3031','2014-2972','2020-4568','2014-3000','2006-6034','2013-3671',
       '2015-5283','2012-3854','2015-6672','2013-2657','2021-0762','2001-3265','2013-2885'
     )
  ON CONFLICT (student_id, course_id) DO NOTHING;

  RAISE NOTICE 'ITE241 configured for MAED-TVLE section 241; verified roster count: %', v_found;
END $$;
