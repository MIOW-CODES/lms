-- MIOW-LMS PRODUCTION APPLY v2 (single-statement atomic run; safe to re-run)

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



DO $ict1_all$

BEGIN

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

-- ===== 20261004000003 · ICT 1 - LAB branding + B8 =====

-- =============================================================================
-- MIOW-LMS: ICT1 → "ICT 1 - LAB" (College 2nd Year) + students → section B8
-- =============================================================================
-- Fixes the course card badge ("Grade 10 (G10)") and missing student sections.
--
-- Background / bug source:
--   20261003000002_seed_it10_ict1.sql inserted ICT1 as
--     (title 'ICT 1', code 'ICT1', grade_level 10, color 'indigo')
--   i.e. grade_level = 10 with education_level defaulting to 'jhs'. The course
--   card badge renders levelLabel(c.grade_level)
--   (src/components/courses/course-card-grid.tsx:36 → src/lib/course-levels.ts),
--   so grade_level 10 showed "Grade 10 (G10)".
--
--   20261004000001_seed_ict1_meeting_members.sql created the 46 college student
--   profiles without a section (documented "Section defaults to NULL", only
--   CALUNOD kept B8 from the TVE100 roster).
--
-- College 2nd Year pattern (mirrors TVE100 seed 20260923000001 and the unified
-- level model of 20260831000003 / 20260923000000):
--   grade_level      = 14                (13=College 1st .. 16=College 4th;
--                                         badge label "College — 2nd Year")
--   education_level  = 'college'
--   college_year     = 2
--   grading_system   = 'college_semestral'   (college grading path in app code)
-- Program is intentionally left untouched: the ICT1 roster spans BTLED-IA and
-- BTLED-HE, so no single program value applies.
--
-- Scope: only courses row ICT1 (by code) + profiles.section for the 46 ICT1
-- students (by the exact student_id list from 20261004000001). Meetings,
-- meeting members, enrollments, IT10, and sections Omega/Phi/Sigma/Tau are
-- NOT touched.
-- Idempotent: plain UPDATEs against stable keys; safe to run any number of
-- times (also safe if executed outside the _migrations bookkeeping).
-- =============================================================================

-- ── 1. Course ICT1: title + college 2nd-year metadata ────────────────────────
UPDATE public.courses
SET
  title           = 'ICT 1 - LAB',
  grade_level     = 14,
  education_level = 'college',
  college_year    = 2,
  grading_system  = 'college_semestral'
WHERE code = 'ICT1';

-- ── 2. Section B8 for the 46 ICT1 students ───────────────────────────────────
-- student_id list copied from temp_ict1_roster in 20261004000001 (46 rows).
-- Only profiles.section is written; no other profile field is modified.
UPDATE public.profiles p
SET section = 'B8'
FROM (
  VALUES
    ('2024-2699'),
    ('2024-2712'),
    ('2024-2017'),
    ('2024-1977'),
    ('2023-3693'),
    ('2024-2724'),
    ('2022-4168'),
    ('2024-3145'),
    ('2024-2739'),
    ('2023-1550'),
    ('2024-2094'),
    ('2024-2084'),
    ('2024-2753'),
    ('2024-2766'),
    ('2024-2776'),
    ('2024-2683'),
    ('2022-7023'),
    ('2022-6116'),
    ('2024-2503'),
    ('2024-2514'),
    ('2024-0877'),
    ('2024-2530'),
    ('2024-2875'),
    ('2024-2211'),
    ('2024-2557'),
    ('2024-2212'),
    ('2024-2968'),
    ('2022-6850'),
    ('2022-3418'),
    ('2024-2214'),
    ('2024-3172'),
    ('2024-2249'),
    ('2024-2586'),
    ('2024-2599'),
    ('2021-1692'),
    ('2025-0858'),
    ('2024-1459'),
    ('2024-3454'),
    ('2024-2606'),
    ('2024-2287'),
    ('2024-2614'),
    ('2024-2627'),
    ('2025-2624'),
    ('2024-1710'),
    ('2024-2655'),
    ('2020-3440')
) AS v(student_id)
WHERE p.student_id = v.student_id;

-- ===== 20261004000004 · clone TVE100 quizzes/exams → ICT1 =====

-- MIOW-LMS: Clone TVE100 assessments (quizzes + assignments) onto ICT1.
--
-- Why: Quizzes 1-4 + Prelim Exam (each with attached handouts and question
-- sets) were authored through the app UI against course TVE100, so they live
-- only in the production DB — there is no local seed to copy from. ICT1
-- ('ICT 1 - LAB') shares the same B8 student cohort and must receive the SAME
-- assessments. This migration therefore clones the rows at apply-time: against
-- the local (empty) DB it is a no-op; against production it does the real clone.
--
-- Clone rules (idempotent — safe to run any number of times):
--   * Source: every non-deleted (deleted_at IS NULL) quizzes/assignments row of
--     course code 'TVE100' that is not already present on course code 'ICT1',
--     where "present" = an ICT1 row (of the same table) with the same
--     case-insensitive title (lower(btrim(title))). A soft-deleted ICT1 row with
--     the same title still counts as present, so a deliberate teacher deletion
--     is never resurrected into a duplicate.
--   * Quizzes copy source columns verbatim except id/course_id (new quiz id,
--     course_id = ICT1): title, duration_minutes, allow_retake, max_attempts,
--     retake_score_policy, attachments, score_released, answer_key_released,
--     question_count, created_at. deleted_at is left NULL (sources are active).
--   * quiz_questions of each cloned quiz are copied verbatim (question, options,
--     correct_answer, position) with new ids re-pointed at the new quiz id.
--   * Assignments copy source columns verbatim except id/course_id: title,
--     description, due_date, total_points, component_type, attachments,
--     score_released, created_at.
--   * attachments jsonb is copied as-is (same storage objects/paths — sharing
--     the same files across the two courses is intended).
--   * NO student data is cloned: no submissions, quiz_attempts, grades,
--     quiz_score_overrides, quiz_retake_grants, attendance.
--
-- Row shapes mirror the app exactly (nothing invented):
--   * attachments: jsonb array of {name, url, size, type, path}
--     (src/lib/server/materials.server.ts:44,136-142 and src/lib/lms.ts:240-246;
--     validated by attachmentMeta in src/lib/server/schemas.server.ts:22-28).
--   * component_type enum: 'written_work' | 'performance_task' |
--     'quarterly_exam' (src/lib/lms.ts:216; schemas.server.ts:264,437).
--   * question_count: integer, 0 = show all questions (20260905000000_question_bank.sql).
--   * Soft delete: deleted_at timestamptz NULL = active
--     (20260825093258_5b5b8ed4-4220-4488-9a9a-27e9a95e8049.sql; app filters
--     deleted_at IS NULL in src/lib/server/quizzes.server.ts:11).
--
-- Both courses are resolved by their UNIQUE code (TVE100 / ICT1), never by a
-- hard-coded uuid, so the migration is correct on any environment. If either
-- course is missing, it raises a notice and does nothing.

<<clone_tve100_assessments_to_ict1>>
DECLARE
  v_src_id       uuid;
  v_dst_id       uuid;
  v_new_quiz_id  uuid;
  v_q_count      integer;
  v_quizzes      integer := 0;
  v_questions    integer := 0;
  v_assignments  integer := 0;
  r              record;
BEGIN
  SELECT id INTO v_src_id FROM public.courses WHERE code = 'TVE100';
  SELECT id INTO v_dst_id FROM public.courses WHERE code = 'ICT1';

  IF v_src_id IS NULL OR v_dst_id IS NULL THEN
    RAISE NOTICE 'clone_tve100_assessments_to_ict1: TVE100 (%) or ICT1 (%) missing - nothing to do',
      v_src_id, v_dst_id;
    RETURN;
  END IF;

  -- ── 1. Quizzes + their questions ──────────────────────────────────────────
  FOR r IN
    SELECT q.*
    FROM public.quizzes q
    WHERE q.course_id = v_src_id
      AND q.deleted_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.quizzes d
        WHERE d.course_id = v_dst_id
          AND lower(btrim(d.title)) = lower(btrim(q.title))
      )
    ORDER BY q.created_at, lower(btrim(q.title))
  LOOP
    -- Re-check inside the loop: two source quizzes may share a title (the
    -- cursor snapshot would otherwise clone both).
    IF EXISTS (
      SELECT 1
      FROM public.quizzes d
      WHERE d.course_id = v_dst_id
        AND lower(btrim(d.title)) = lower(btrim(r.title))
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.quizzes (
      course_id, title, duration_minutes, allow_retake, max_attempts,
      retake_score_policy, attachments, score_released, answer_key_released,
      question_count, created_at
    ) VALUES (
      v_dst_id, r.title, r.duration_minutes, r.allow_retake, r.max_attempts,
      r.retake_score_policy, r.attachments, r.score_released, r.answer_key_released,
      r.question_count, r.created_at
    )
    RETURNING id INTO v_new_quiz_id;

    INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
    SELECT v_new_quiz_id, qq.question, qq.options, qq.correct_answer, qq.position
    FROM public.quiz_questions qq
    WHERE qq.quiz_id = r.id;

    GET DIAGNOSTICS v_q_count = ROW_COUNT;
    v_questions := v_questions + v_q_count;
    v_quizzes   := v_quizzes + 1;
  END LOOP;

  -- ── 2. Assignments ────────────────────────────────────────────────────────
  FOR r IN
    SELECT a.*
    FROM public.assignments a
    WHERE a.course_id = v_src_id
      AND a.deleted_at IS NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public.assignments d
        WHERE d.course_id = v_dst_id
          AND lower(btrim(d.title)) = lower(btrim(a.title))
      )
    ORDER BY a.created_at, lower(btrim(a.title))
  LOOP
    IF EXISTS (
      SELECT 1
      FROM public.assignments d
      WHERE d.course_id = v_dst_id
        AND lower(btrim(d.title)) = lower(btrim(r.title))
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.assignments (
      course_id, title, description, due_date, total_points,
      component_type, attachments, score_released, created_at
    ) VALUES (
      v_dst_id, r.title, r.description, r.due_date, r.total_points,
      r.component_type, r.attachments, r.score_released, r.created_at
    );

    v_assignments := v_assignments + 1;
  END LOOP;

  RAISE NOTICE 'clone_tve100_assessments_to_ict1: cloned % quizzes (% questions) and % assignments',
    v_quizzes, v_questions, v_assignments;
END clone_tve100_assessments_to_ict1;

-- ===== 20261004000005 · Week 5-7 materials + Prelim coverage =====

-- MIOW-LMS: ICT1 — add Week 5-7 lecture slides + Prelim Exam coverage (Weeks 1-7)
--
-- Scope: course code 'ICT1' ONLY. TVE100 is never read for writes and never
-- modified. Every statement is keyed by the ICT1 course id resolved from
-- public.courses WHERE code = 'ICT1' (never a hard-coded uuid — the course id
-- is gen_random_uuid() per environment, see 20261003000002_seed_it10_ict1.sql).
--
-- Why this shape (mirrors the app exactly — nothing invented):
--   * The app has NO `materials` table. Course files live as `attachments`
--     jsonb rows on `assignments`/`quizzes` and are surfaced by MaterialManager
--     (src/components/courses/material-manager.tsx:16; used at
--     assignments-section.tsx:74, worksheets-section.tsx:84 and the edit
--     modals). So the 3 lecture files are attached to a real ICT1 assignment.
--   * attachments: jsonb array of {name, url, size, type, path}
--     (src/lib/server/materials.server.ts:44,136-142; src/lib/lms.ts:240-246;
--     attachmentMeta in src/lib/server/schemas.server.ts:22-28).
--   * path: '<course_id>/material_<epoch_ms>_<8hex>.<ext>'
--     (materials.server.ts:129-135). Storage object lives in bucket
--     'course-materials' (materials.server.ts:12): Supabase Storage in
--     production, local filesystem STORAGE_PATH/storage/course-materials/<path>
--     locally (src/integrations/db/storage.ts:1-9,
--     src/integrations/db/client.server.ts:88-91).
--   * url: '/api/public/material?p=' || encodeURIComponent(path) =
--     materialUrlForPath (materials.server.ts:46-48). For these paths the only
--     encoded character is '/' -> '%2F', so the SQL-built url is byte-identical
--     to the app's.
--   * component_type enum: 'written_work' | 'performance_task' |
--     'quarterly_exam' (src/lib/lms.ts:216). No enum value fits "materials";
--     the carrier assignment uses 'written_work'.
--   * Soft delete: deleted_at timestamptz NULL = active; all reads filter
--     deleted_at IS NULL (quizzes.server.ts:11), so soft-deleted rows are left
--     alone (a deliberate teacher deletion is never resurrected).
--
-- What it does (all ICT1-only):
--   (a) Upserts ONE assignment titled 'Week 5-7 Lecture Materials' carrying the
--       3 lecture slides as attachments. Present = same case-insensitive title
--       OR an existing attachment with one of our storage paths, so re-runs can
--       never duplicate. If present, attachments are merged (union by path) and
--       a NULL/empty description is filled in; existing description text is
--       never overwritten.
--   (b) Every active ICT1 row (assignments + quizzes) titled ILIKE '%prelim%'
--       (the Prelim Exam; in production it exists because 20261004000004 clones
--       it from TVE100 first):
--         * description gains the line "Coverage: Weeks 1-7" — appended to any
--           existing text (never destroyed); skipped when the line is already
--           there (idempotent).
--         * the same 3 lecture attachments are merged into the row's
--           attachments (union by path; existing attachments preserved) — that
--           is where the app shows exam materials (MaterialManager above).
--       NOTE on quizzes: public.quizzes has NO description column in any
--       migration of this repo (title/attachments/retake/score-release fields
--       only). If a description column is ever present, the line is merged into
--       it; otherwise the coverage is surfaced in the only free text a quiz
--       has — the title — as an additive suffix " (Coverage: Weeks 1-7)",
--       applied only when the title does not already mention "week". Both
--       branches are idempotent and preserve all pre-existing text.
--   (c) No-op everywhere else: if ICT1 is missing, the block raises a NOTICE
--       and returns; if no Prelim row exists yet (local DB before/without the
--       clone), (b) simply matches zero rows and leaves a correct guarded
--       UPDATE for when the row appears.
--
-- Files (attached by name/size/type; binary objects are placed in the
-- 'course-materials' bucket out-of-band — local copies under ./storage/, prod
-- via /tmp/opencode/upload-ict1-materials.mjs):
--   ICT1_Week5 Online Collaboration Tools.pptx   85918 bytes
--   ICT1_Week6 Learning Management Systems.pptx  79130 bytes
--   ICT1_Week7 Multimedia in Education.pptx      82712 bytes
--   type: application/vnd.openxmlformats-officedocument.presentationml.presentation
--
-- Idempotent: safe to run any number of times (also outside _migrations
-- bookkeeping). Verified locally with fixture rows + re-run no-op check.

<<ict1_week5_7_materials>>
DECLARE
  v_course       uuid;
  v_atts         jsonb := '[]'::jsonb;   -- the 3 lecture attachments for THIS env
  r              record;
  r2             record;
  v_path         text;
  v_existing     jsonb;
  v_merged       jsonb;
  v_desc         text;
  v_title        text;
  v_asg_ins      integer := 0;
  v_asg_upd      integer := 0;
  v_qz_upd       integer := 0;
  v_prelim_hits  integer := 0;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';

  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_week5_7_materials: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  -- ── Build the 3 attachment objects, paths prefixed with THIS environment's
  --    ICT1 id (matches materials.server.ts:129-135 naming) ─────────────────
  FOR r2 IN
    SELECT * FROM (VALUES
      ('ICT1_Week5 Online Collaboration Tools.pptx',  'material_1759632000000_a1b2c3d4.pptx', 85918),
      ('ICT1_Week6 Learning Management Systems.pptx', 'material_1759632001000_b2c3d4e5.pptx', 79130),
      ('ICT1_Week7 Multimedia in Education.pptx',     'material_1759632002000_c3d4e5f6.pptx', 82712)
    ) AS t(fname, fsuffix, fsize)
  LOOP
    v_path := v_course::text || '/' || r2.fsuffix;
    v_atts := v_atts || jsonb_build_array(jsonb_build_object(
      'name', r2.fname,
      'url',  '/api/public/material?p=' || replace(v_path, '/', '%2F'),
      'size', r2.fsize,
      'type', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'path', v_path
    ));
  END LOOP;

  -- ── (a) 'Week 5-7 Lecture Materials' assignment on ICT1 ──────────────────
  FOR r IN
    SELECT id, description, attachments
    FROM public.assignments
    WHERE course_id = v_course
      AND deleted_at IS NULL
      AND (
        lower(btrim(title)) = 'week 5-7 lecture materials'
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements(attachments) e
          WHERE e->>'path' IN (
            v_course::text || '/material_1759632000000_a1b2c3d4.pptx',
            v_course::text || '/material_1759632001000_b2c3d4e5.pptx',
            v_course::text || '/material_1759632002000_c3d4e5f6.pptx'
          )
        )
      )
  LOOP
    v_merged := COALESCE(r.attachments, '[]'::jsonb) || (
      SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
      FROM jsonb_array_elements(v_atts) n
      WHERE NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(COALESCE(r.attachments, '[]'::jsonb)) e
        WHERE e->>'path' = n->>'path'
      )
    );
    v_desc := r.description;
    IF v_desc IS NULL OR btrim(v_desc) = '' THEN
      v_desc := 'Lecture slides for Weeks 5-7: Week 5 - Online Collaboration Tools, '
             || 'Week 6 - Learning Management Systems, Week 7 - Multimedia in Education.';
    END IF;
    UPDATE public.assignments
    SET attachments = v_merged, description = v_desc
    WHERE id = r.id;
    v_asg_upd := v_asg_upd + 1;
  END LOOP;

  IF v_asg_upd = 0 THEN
    INSERT INTO public.assignments
      (course_id, title, description, total_points, component_type, attachments)
    VALUES (
      v_course,
      'Week 5-7 Lecture Materials',
      'Lecture slides for Weeks 5-7: Week 5 - Online Collaboration Tools, '
        || 'Week 6 - Learning Management Systems, Week 7 - Multimedia in Education.',
      100,
      'written_work',
      v_atts
    );
    v_asg_ins := 1;
  END IF;

  -- ── (b1) Prelim rows on ICT1 ASSIGNMENTS: coverage line + attachments ────
  FOR r IN
    SELECT id, title, description, attachments
    FROM public.assignments
    WHERE course_id = v_course
      AND deleted_at IS NULL
      AND title ILIKE '%prelim%'
  LOOP
    v_prelim_hits := v_prelim_hits + 1;
    v_merged := COALESCE(r.attachments, '[]'::jsonb) || (
      SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
      FROM jsonb_array_elements(v_atts) n
      WHERE NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(COALESCE(r.attachments, '[]'::jsonb)) e
        WHERE e->>'path' = n->>'path'
      )
    );
    v_desc := r.description;
    IF v_desc IS NULL OR v_desc !~* 'weeks?[[:space:]]*1[[:space:]]*-[[:space:]]*7' THEN
      IF v_desc IS NULL OR btrim(v_desc) = '' THEN
        v_desc := 'Coverage: Weeks 1-7';
      ELSE
        v_desc := btrim(v_desc) || E'\n\nCoverage: Weeks 1-7';
      END IF;
    END IF;
    UPDATE public.assignments
    SET description = v_desc, attachments = v_merged
    WHERE id = r.id;
    v_asg_upd := v_asg_upd + 1;
  END LOOP;

  -- ── (b2) Prelim rows on ICT1 QUIZZES: coverage line + attachments ────────
  FOR r IN
    SELECT id, title, attachments
    FROM public.quizzes
    WHERE course_id = v_course
      AND deleted_at IS NULL
      AND title ILIKE '%prelim%'
  LOOP
    v_prelim_hits := v_prelim_hits + 1;
    v_merged := COALESCE(r.attachments, '[]'::jsonb) || (
      SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
      FROM jsonb_array_elements(v_atts) n
      WHERE NOT EXISTS (
        SELECT 1
        FROM jsonb_array_elements(COALESCE(r.attachments, '[]'::jsonb)) e
        WHERE e->>'path' = n->>'path'
      )
    );

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'quizzes' AND column_name = 'description'
    ) THEN
      -- Future-proof: if quizzes ever grows a description column, merge there
      -- (statement is only prepared/executed inside this branch).
      UPDATE public.quizzes q
      SET description =
        CASE
          WHEN q.description IS NULL OR q.description !~* 'weeks?[[:space:]]*1[[:space:]]*-[[:space:]]*7'
            THEN CASE
              WHEN q.description IS NULL OR btrim(q.description) = '' THEN 'Coverage: Weeks 1-7'
              ELSE btrim(q.description) || E'\n\nCoverage: Weeks 1-7'
            END
          ELSE q.description
        END,
        attachments = v_merged
      WHERE q.id = r.id;
    ELSE
      -- No description column in this schema: surface the coverage in the only
      -- free text a quiz row has — an additive title suffix, only when the
      -- title does not already mention "week" (idempotent, text preserved).
      v_title := r.title;
      IF v_title !~* 'week' THEN
        v_title := v_title || ' (Coverage: Weeks 1-7)';
      END IF;
      UPDATE public.quizzes
      SET title = v_title, attachments = v_merged
      WHERE id = r.id;
    END IF;
    v_qz_upd := v_qz_upd + 1;
  END LOOP;

  RAISE NOTICE
    'ict1_week5_7_materials: assignment inserted %, assignment rows updated %, quiz rows updated %, prelim rows matched %',
    v_asg_ins, v_asg_upd, v_qz_upd, v_prelim_hits;
END ict1_week5_7_materials;

END $ict1_all$;

-- ============================================================
-- VERIFICATION + the exact Storage folder/paths for the 3 PPTX.
-- After running, look at the RESULTS below:
--   storage_folder → create this folder in Storage → course-materials
--   then upload the 3 files from ~/Documents/ICT1-upload-ready/
-- ============================================================
SELECT c.id AS storage_folder, 'course-materials' AS bucket
FROM public.courses c WHERE c.code = 'ICT1';

SELECT a.title, att->>'path' AS upload_path, att->>'name' AS file_name
FROM public.assignments a
JOIN public.courses c ON c.id = a.course_id
CROSS JOIN LATERAL jsonb_array_elements(a.attachments) att
WHERE c.code = 'ICT1' AND att->>'name' ILIKE '%.pptx'
ORDER BY att->>'path';

SELECT m.label, m.days_of_week, m.start_time, m.end_time,
       (SELECT count(*) FROM public.course_meeting_members mm WHERE mm.meeting_id = m.id) AS members
FROM public.course_meetings m JOIN public.courses c ON c.id = m.course_id
WHERE c.code = 'ICT1' ORDER BY m.sort_order;

SELECT c.title, c.grade_level, c.education_level,
       (SELECT count(*) FROM public.enrollments e WHERE e.course_id = c.id) AS enrolled
FROM public.courses c WHERE c.code = 'ICT1';
