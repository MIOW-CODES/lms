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
