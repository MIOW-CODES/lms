-- MIOW-LMS: Seed TVE100 class roster from uploaded PDF
-- TVE100 - The Teacher and the Community (BTVTED-DT / BTLED-HE)
-- Section B8, SY 2026-2027 Semester 1, TTh 6:00-7:30 PM, CED-203

-- First ensure the course exists
INSERT INTO public.courses (id, title, code, grade_level, education_level, college_year, program, color, grading_system, days_of_week, start_time, end_time)
VALUES (
  'e1000000-0000-4000-8000-000000000100',
  'The Teacher and the Community, School Culture & Organizational Leadership',
  'TVE100',
  14,
  'college',
  2,
  'BTVTED-DT',
  'violet',
  'college_semestral',
  '{"tue","thu"}',
  '18:00',
  '19:30'
) ON CONFLICT (code) DO UPDATE SET
  title = EXCLUDED.title,
  grade_level = EXCLUDED.grade_level,
  education_level = EXCLUDED.education_level,
  college_year = EXCLUDED.college_year,
  program = EXCLUDED.program,
  grading_system = EXCLUDED.grading_system,
  days_of_week = EXCLUDED.days_of_week,
  start_time = EXCLUDED.start_time,
  end_time = EXCLUDED.end_time;

-- Seed the 48 students (year 2-4, BTVTED-DT and BTLED-HE)
-- Using deterministic UUIDs based on student_id for idempotent re-runs
INSERT INTO public.profiles (id, student_id, full_name, role, grade_level, section, email)
VALUES
  (gen_random_uuid(), '2025-2517', 'Alastra, Gel Lord B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-3325', 'Alfonso, Bryan P.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2024-0218', 'Andrade, Eunice Pearl A.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-0741', 'Atillo, Kristina Gabriella C.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2351', 'Bancale, Regie M.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2451', 'Banzon, Bob Erod G.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2490', 'Baring, Joyce S.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2342', 'Benejol, Charmine C.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2000', 'Bonsalagan, Sittie Ayera Jehanne B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2788', 'Calago, Abigail E.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2020-3440', 'Calunod, Kimberly B.', 'student', 16, 'B8', NULL),
  (gen_random_uuid(), '2025-2085', 'Crispo, Derrick B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2287', 'Curayag, Jirah Mae C.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2026-3165', 'Cutad, Craciana Lury P.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2024-0660', 'De Guzman, Kris Lawrence A.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-2190', 'Diaz, Ryzyl H.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-1322', 'Dioso, Jhon Rhyson H.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-1003', 'Dumaguin, Zach Philippe N.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2023-2552', 'Enrique, Nicko A.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-1813', 'Fernandez, Germaine E.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2726', 'Gumanit, Cyrich B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2023-1219', 'Hermosilla, Nicole Alessandra T.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-3358', 'Jayme, LP May S.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2023-1973', 'Kilat, Clint Joshua B.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-1307', 'Leyran, Krishna Dorothy M.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2022-4898', 'Limpangog, Ella Marie P.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-1187', 'Lumantas, Miko Paolo L.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2389', 'Lura, Freexia Greece', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-1189', 'Manos, Lorenzuela Marie C.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-1997', 'Marzo, Yanka Isabelle B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2023-3370', 'Montecalvo, Christian Reighl T.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-0901', 'Navarette, Katrice D.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2848', 'Olita, Jennylyn C.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2083', 'Pat, Earl Ivan S.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2194', 'Patria, Arif Kyle B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2023-3978', 'Radam, Deanne Monique G.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2024-1567', 'Ramos, Lavinia Belle A.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-0711', 'Sabunod, Ron Michael B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2353', 'Salahay, Jay-Boy G.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2024-2631', 'Salas, Aaron Ray D.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-1819', 'Semblante, Kyza Marie M.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2024-2348', 'Sulague, Shiela Mae A.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2619', 'Tañola, Jennifer U.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-3270', 'Tiples, Jasmine M.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2024-1899', 'Vicoy, Jeremy Ryan L.', 'student', 15, 'B8', NULL),
  (gen_random_uuid(), '2025-1820', 'Villaraza, Jhon Lloyd G.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-0897', 'Villaruel, Kim B.', 'student', 14, 'B8', NULL),
  (gen_random_uuid(), '2025-2487', 'Yu Tiamco, Zharich B.', 'student', 14, 'B8', NULL)
ON CONFLICT (student_id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  grade_level = EXCLUDED.grade_level,
  section = EXCLUDED.section;

-- Auto-enroll all B8 students into TVE100
INSERT INTO public.enrollments (student_id, course_id)
SELECT p.id, 'e1000000-0000-4000-8000-000000000100'
FROM public.profiles p
WHERE p.section = 'B8' AND p.role = 'student'
ON CONFLICT (student_id, course_id) DO NOTHING;

-- Add college sections for BTVTED-DT program
-- (These are common sections in the CTE department)
COMMENT ON TABLE public.enrollments IS 'Student-course enrollment junction. College sections: B1-B12 for BTVTED-DT, HE1-HE4 for BTLED-HE';
