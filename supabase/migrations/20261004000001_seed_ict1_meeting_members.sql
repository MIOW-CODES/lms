-- =============================================================================
-- MIOW-LMS: Seed ICT1 Student Profiles, Course Enrollments & Meeting Members
-- Course: ICT1 (TLE105, S.Y. 2026-2027 Semester 1)
-- =============================================================================
-- 1. Create/upsert profiles for 46 college students (BTLED-IA & BTLED-HE).
--    Credentials follow the 20260924000000 / 20260924000003 convention:
--      * email      -> firstname.lastname@g.msuiit.edu.ph
--      * PIN        -> student_id (plaintext legacy fallback)
--      * pin_hash   -> bcrypt(student_id)
--    College year levels mapped to unified grade_level (12 + year):
--      * Year 2 -> 14
--      * Year 3 -> 15
--      * Year 4 -> 16
--    Section defaults to NULL (or preserves existing section e.g. B8 for Calunod).
-- 2. Enroll all 46 students into course ICT1 (public.enrollments).
-- 3. Assign students to course meetings (public.course_meeting_members):
--      * Lecture (Tue 08:00-10:00): 45 students (all except 2020-3440)
--      * Lab 1   (Tue 15:00-18:00): 22 students
--      * Lab 2   (Thu 15:00-18:00): 21 students
--    Edge cases per source PDFs:
--      * MACAYAN, PAIRAT, Saure: Lecture-only (no lab assignment)
--      * CALUNOD: Lab 2 only (not in lecture, enrolled in ICT1)
-- Meeting capacities (45 / 23 / 22) are left untouched.
-- Idempotent: safe to run on any environment, any number of times.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA IF NOT EXISTS private;

-- Lowercase + strip diacritics + keep only [a-z0-9].
-- Mirrors 20260924000000 / 20260924000003; idempotent re-declaration.
CREATE OR REPLACE FUNCTION private.miow_slug(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(
    translate(
      lower(coalesce(input, '')),
      'áàâäãåéèêëíìîïóòôöõúùûüñçýÿÁÀÂÄÃÅÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇÝ',
      'aaaaaaeeeeiiiiooooouuuuncyyAAAAAAEEEEIIIIOOOOOUUUUNCY'
    ),
    '[^a-z0-9]',
    '',
    'g'
  );
$$;

-- ── Temporary mapping table for ICT1 student roster ──────────────────────────
CREATE TEMP TABLE temp_ict1_roster (
  student_id   text PRIMARY KEY,
  full_name    text NOT NULL,
  gender       text NOT NULL,
  college_year int NOT NULL,
  grade_level  int NOT NULL,
  program      text NOT NULL,
  in_lecture   boolean NOT NULL,
  in_lab1      boolean NOT NULL,
  in_lab2      boolean NOT NULL
) ON COMMIT PRESERVE ROWS;

INSERT INTO temp_ict1_roster (
  student_id, full_name, gender, college_year, grade_level, program, in_lecture, in_lab1, in_lab2
) VALUES
  ('2024-2699', 'ACOSTA, Axel Rose V.',           'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2712', 'AMEROL, Jenan M.',               'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2017', 'APOG, Nipo Cyrus T.',            'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-1977', 'AQUINO, Rogelio Jr. A.',         'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2023-3693', 'ARAT, RAY GABRIEL V.',           'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2724', 'BALONDO, Margaret T.',           'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2022-4168', 'BENOSA, SHIPHRAH',               'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-3145', 'BRAGA, Charish O.',              'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2739', 'BUHIAN, Irish D.',               'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2023-1550', 'BUSANO, JOHN DALE S.',           'M', 4, 16, 'BTLED-IA', true,  false, true),
  ('2024-2094', 'CAÑETE, Isah Jade L.',           'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2084', 'CANONG, Prince Daryl B.',        'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2753', 'CENTILLAS, Miccah Ferd F.',      'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2766', 'DANGCAL, Sophia V.',             'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2776', 'DIZON, Naomi Joy V.',            'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2683', 'DONIOS, Zehntner C.',            'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2022-7023', 'DORON, SHANE PEARL ANDREA A.',   'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2022-6116', 'DUGUIL, JULIUS G.',              'M', 4, 16, 'BTLED-IA', true,  false, true),
  ('2024-2503', 'FABRIA, Dave R.',                'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2514', 'GALLEGO, Novy Gwyneth P.',       'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-0877', 'GOMEZ, Archer John D.',          'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2530', 'HADJI AZIS, Nasrollah M.',       'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2875', 'JUSOY, BRYAN KYLE A.',           'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2211', 'LONGCOB, Rees O.',               'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2557', 'LUCEÑO, Jersie A.',              'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2212', 'LUMAMPA, Najieb J.',             'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2968', 'MAATA, Christian Lloyd B.',      'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2022-6850', 'MACABATO, ALEDAH SAPHIA P.',     'F', 4, 16, 'BTLED-IA', true,  true,  false),
  ('2022-3418', 'MACAYAN, AUDREY MARIE C.',       'F', 4, 16, 'BTLED-IA', true,  false, false),
  ('2024-2214', 'MAGHINAY, Measmerize S.',        'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-3172', 'MANGONDATO, Farmillah A.',       'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2249', 'NICANOR, Steven-Roxxell P.',     'M', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2586', 'OBNIMAGA, Reziel Joy P.',        'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2599', 'PAGTALUNAN, Mark Anthony C.',    'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2021-1692', 'PAIRAT, SAIRA A.',               'F', 2, 14, 'BTLED-HE', true,  false, false),
  ('2025-0858', 'Paloma, Mekhyle P.',             'M', 2, 14, 'BTLED-HE', true,  true,  false),
  ('2024-1459', 'PANIMDIM, Johfrit Johnn C.',     'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-3454', 'PARAGOSO, CHIMAR E.',            'M', 2, 14, 'BTLED-HE', true,  false, true),
  ('2024-2606', 'PAUDAC, Hamza M.',               'M', 3, 15, 'BTLED-IA', true,  false, true),
  ('2024-2287', 'QUIAPO, Anieca Kim M.',          'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2614', 'RABOR, Kate Nicole A.',          'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2627', 'SABERON, May Ann S.',            'F', 3, 15, 'BTLED-IA', true,  false, true),
  ('2025-2624', 'Saure, Gena D.',                 'F', 2, 14, 'BTLED-HE', true,  false, false),
  ('2024-1710', 'SEBLERO, Ma. Josie Grace T.',    'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2024-2655', 'TADAY, Jolycca May V.',          'F', 3, 15, 'BTLED-IA', true,  true,  false),
  ('2020-3440', 'CALUNOD, KIMBERLY B.',           'F', 4, 16, 'BTLED-HE', false, false, true);

-- ── 1. Insert student profiles ────────────────────────────────────────────────
-- Generates institutional credentials per 20260924000000 convention.
-- On conflict with existing profiles (e.g. CALUNOD already in TVE100 roster),
-- existing full_name/credentials are preserved via COALESCE.
INSERT INTO public.profiles (
  id,
  student_id,
  email,
  pin,
  pin_hash,
  full_name,
  role,
  grade_level
)
SELECT
  gen_random_uuid(),
  t.student_id,
  private.miow_slug(
    regexp_replace(
      trim(substring(t.full_name from position(',' in t.full_name) + 1)),
      '\s+[A-Za-z]\.?\s*$',
      ''
    )
  )
    || '.'
    || private.miow_slug(trim(split_part(t.full_name, ',', 1)))
    || '@g.msuiit.edu.ph',
  t.student_id,
  extensions.crypt(t.student_id, extensions.gen_salt('bf', 10)),
  t.full_name,
  'student'::public.profile_role,
  t.grade_level
FROM temp_ict1_roster t
ON CONFLICT (student_id) DO UPDATE SET
  full_name = COALESCE(NULLIF(public.profiles.full_name, ''), EXCLUDED.full_name),
  grade_level = EXCLUDED.grade_level,
  email = COALESCE(public.profiles.email, EXCLUDED.email),
  pin = COALESCE(public.profiles.pin, EXCLUDED.pin),
  pin_hash = COALESCE(public.profiles.pin_hash, EXCLUDED.pin_hash);

-- ── 2. Enroll all 46 students into course ICT1 ───────────────────────────────
INSERT INTO public.enrollments (student_id, course_id)
SELECT p.id, c.id
FROM public.profiles p
JOIN temp_ict1_roster t ON t.student_id = p.student_id
CROSS JOIN public.courses c
WHERE c.code = 'ICT1'
ON CONFLICT (student_id, course_id) DO NOTHING;

-- ── 3. Assign students to course meetings ────────────────────────────────────
-- Lecture meeting (Tue 08:00-10:00): 45 students (all except 2020-3440)
INSERT INTO public.course_meeting_members (meeting_id, student_id)
SELECT m.id, p.id
FROM public.course_meetings m
JOIN public.courses c ON c.id = m.course_id
CROSS JOIN public.profiles p
JOIN temp_ict1_roster t ON t.student_id = p.student_id
WHERE c.code = 'ICT1'
  AND m.kind = 'lecture'
  AND m.label = 'Lecture'
  AND t.in_lecture = true
ON CONFLICT (meeting_id, student_id) DO NOTHING;

-- Lab 1 meeting (Tue 15:00-18:00): 22 students
INSERT INTO public.course_meeting_members (meeting_id, student_id)
SELECT m.id, p.id
FROM public.course_meetings m
JOIN public.courses c ON c.id = m.course_id
CROSS JOIN public.profiles p
JOIN temp_ict1_roster t ON t.student_id = p.student_id
WHERE c.code = 'ICT1'
  AND m.kind = 'lab'
  AND m.label = 'Lab 1'
  AND t.in_lab1 = true
ON CONFLICT (meeting_id, student_id) DO NOTHING;

-- Lab 2 meeting (Thu 15:00-18:00): 21 students
INSERT INTO public.course_meeting_members (meeting_id, student_id)
SELECT m.id, p.id
FROM public.course_meetings m
JOIN public.courses c ON c.id = m.course_id
CROSS JOIN public.profiles p
JOIN temp_ict1_roster t ON t.student_id = p.student_id
WHERE c.code = 'ICT1'
  AND m.kind = 'lab'
  AND m.label = 'Lab 2'
  AND t.in_lab2 = true
ON CONFLICT (meeting_id, student_id) DO NOTHING;

-- ── 4. Clean up temporary mapping table ──────────────────────────────────────
DROP TABLE IF EXISTS temp_ict1_roster;
