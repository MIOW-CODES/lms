-- =============================================================================
-- MIOW-LMS: Seed IT10 (by section) + ICT1 (lecture + 2 labs)
-- =============================================================================
-- Idempotent: safe to run on any environment, any number of times.
-- Depends on 20261003000001 (sections Omega/Phi/Sigma/Tau, course_sections,
-- course_meetings).
-- =============================================================================

-- ── 1. IT10 course offering (Grade 10) ───────────────────────────────────────
INSERT INTO public.courses (title, code, grade_level, color)
VALUES ('Information Technology 10', 'IT10', 10, 'teal')
ON CONFLICT (code) DO NOTHING;

-- ── 2. Enroll every Grade 10 student into IT10 (all four sections) ──────────
INSERT INTO public.enrollments (student_id, course_id)
SELECT p.id, c.id
FROM public.profiles p
JOIN public.courses c ON c.code = 'IT10'
WHERE p.role = 'student'
  AND p.grade_level = 10
  AND p.deleted_at IS NULL
ON CONFLICT (student_id, course_id) DO NOTHING;

-- ── 3. Link IT10 to the four Grade 10 sections (re-run of 0001's link) ───────
INSERT INTO public.course_sections (course_id, section_id)
SELECT c.id, s.id
FROM public.courses c
JOIN public.sections s
  ON s.education_level = 'jhs' AND s.name IN ('Omega', 'Phi', 'Sigma', 'Tau')
WHERE c.code = 'IT10'
ON CONFLICT DO NOTHING;

-- ── 4. ICT1 course offering ──────────────────────────────────────────────────
-- Separate course (per stakeholder decision): 1 lecture section of 45 students
-- split into two lab groups (23 + 22).
INSERT INTO public.courses (title, code, grade_level, color)
VALUES ('ICT 1', 'ICT1', 10, 'indigo')
ON CONFLICT (code) DO NOTHING;

-- ── 5. ICT1 meetings: Lecture Tue 8–10 AM (45), Lab 1 Tue 3–6 PM (23),
--        Lab 2 Thu 3–6 PM (22) ───────────────────────────────────────────────
INSERT INTO public.course_meetings
  (course_id, kind, label, days_of_week, start_time, end_time, capacity, sort_order)
SELECT
  c.id,
  v.kind,
  v.label,
  v.days::text[],
  v.st::time,
  v.et::time,
  v.cap,
  v.ord
FROM public.courses c
CROSS JOIN (VALUES
  ('lecture', 'Lecture', '{tue}', '08:00', '10:00', 45, 0),
  ('lab',     'Lab 1',   '{tue}', '15:00', '18:00', 23, 1),
  ('lab',     'Lab 2',   '{thu}', '15:00', '18:00', 22, 2)
) AS v(kind, label, days, st, et, cap, ord)
WHERE c.code = 'ICT1'
  AND NOT EXISTS (
    SELECT 1
    FROM public.course_meetings m
    WHERE m.course_id = c.id AND m.label = v.label
  );
