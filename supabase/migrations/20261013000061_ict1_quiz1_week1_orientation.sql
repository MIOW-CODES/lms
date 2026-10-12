-- Course: ICT1 — Quiz 1 — Week 1 (Course Orientation: Course Information, Schedules, Roadmap, Assessments)
--
-- ICT1 Quiz 1 — 20 multiple-choice questions grounded strictly in the Week 1
-- course-orientation fact sheet for ICT 1 – Information Communication 1
-- (code ICT1, College 3rd Year section B8, Dr. Alan L. Vergara).
-- Knowledge + application quiz only: no lab_task items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 1' exists on ICT1: keep the quiz row and
--     its availability/release state, hard delete its old quiz_questions rows,
--     insert this orientation-based set, refresh duration_minutes = 10 and
--     question_count = 20.
--   * Otherwise: insert the quiz row (opens_at NULL, closes_at now() + 14 days,
--     score_released / answer_key_released false) plus its questions.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_quiz1_week1_orientation: course code ICT1 not found — skipping Quiz 1';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 1' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 1', 10, 20, NULL::timestamptz, now() + interval '14 days', false, false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 1' AND deleted_at IS NULL
  )
  RETURNING id INTO v_quiz;

  IF v_quiz IS NULL THEN
    -- Quiz already exists: replace its question set in place.
    SELECT id INTO v_quiz FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 1' AND deleted_at IS NULL
     ORDER BY created_at
     LIMIT 1;
    DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;
    UPDATE public.quizzes SET duration_minutes = 10, question_count = 20 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz1_week1_orientation: Quiz 1 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz1_week1_orientation: created Quiz 1 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What is the course code of Information Communication 1?', '["ICT1","ICT11","ICT-01","ICOM1"]', 'ICT1'),
    (2,  'What is the full title of the course with code ICT1?', '["Information Communication 1","Introduction to Computing 1","Information and Communications Technology 1","Introduction to Communication 1"]', 'Information Communication 1'),
    (3,  'In which year level and section is the ICT1 class handled?', '["College 3rd Year, section B8","College 2nd Year, section B8","College 3rd Year, section A1","Senior High School Grade 12, section B8"]', 'College 3rd Year, section B8'),
    (4,  'Who is the teacher of ICT 1 – Information Communication 1?', '["Dr. Alan L. Vergara","Dr. Alan L. Veraga","Prof. Alan B. Villanueva","Dr. Alberto L. Vega"]', 'Dr. Alan L. Vergara'),
    (5,  'When is the ICT1 lecture held?', '["Tuesday, 8:00–10:00 AM","Tuesday, 3:00–6:00 PM","Thursday, 8:00–10:00 AM","Thursday, 3:00–6:00 PM"]', 'Tuesday, 8:00–10:00 AM'),
    (6,  'A student arrives for the Tuesday lecture at 8:12 AM. Based on the 10-minute grace period for the lecture, how is the arrival treated?', '["It is past the 10-minute grace period, so the arrival counts as late","It is within the 10-minute grace period, so the arrival counts as on time","The grace period is 15 minutes, so the arrival counts as on time","There is no grace period, and any arrival after 8:00 AM counts as absent"]', 'It is past the 10-minute grace period, so the arrival counts as late'),
    (7,  'When is Lab 1 of ICT1 held?', '["Tuesday, 3:00–6:00 PM","Tuesday, 8:00–10:00 AM","Thursday, 3:00–6:00 PM","Thursday, 8:00–10:00 AM"]', 'Tuesday, 3:00–6:00 PM'),
    (8,  'When is Lab 2 of ICT1 held?', '["Thursday, 3:00–6:00 PM","Tuesday, 3:00–6:00 PM","Thursday, 8:00–10:00 AM","Tuesday, 8:00–10:00 AM"]', 'Thursday, 3:00–6:00 PM'),
    (9,  'A student is free only on Thursday afternoons. Which ICT1 lab session should the student attend?', '["Lab 2 — Thursday, 3:00–6:00 PM","Lab 1 — Tuesday, 3:00–6:00 PM","Lab 1 — Thursday, 3:00–6:00 PM","Lab 2 — Tuesday, 8:00–10:00 AM"]', 'Lab 2 — Thursday, 3:00–6:00 PM'),
    (10, 'Which topic is covered in Week 2 of ICT1?', '["Productivity Tools","Spreadsheet Applications","Presentation Tools","Online Collaboration Tools"]', 'Productivity Tools'),
    (11, 'Which topic is covered in Week 3 of ICT1?', '["Spreadsheet Applications","Productivity Tools","Learning Management Systems","Multimedia in Education"]', 'Spreadsheet Applications'),
    (12, 'Which topic is covered in Week 4 of ICT1?', '["Presentation Tools","Productivity Tools","Online Collaboration Tools","Multimedia in Education"]', 'Presentation Tools'),
    (13, 'Which topic is covered in Week 5 of ICT1?', '["Online Collaboration Tools","Learning Management Systems","Presentation Tools","Spreadsheet Applications"]', 'Online Collaboration Tools'),
    (14, 'Which topic is covered in Week 6 of ICT1?', '["Learning Management Systems","Multimedia in Education","Online Collaboration Tools","Productivity Tools"]', 'Learning Management Systems'),
    (15, 'Which topic is covered in Week 7 of ICT1?', '["Multimedia in Education","Learning Management Systems","Presentation Tools","Online Collaboration Tools"]', 'Multimedia in Education'),
    (16, 'A student wants to master Presentation Tools — the tools used to create slide decks for instruction. Which week of ICT1 is dedicated to this?', '["Week 4 — Presentation Tools","Week 2 — Productivity Tools","Week 5 — Online Collaboration Tools","Week 7 — Multimedia in Education"]', 'Week 4 — Presentation Tools'),
    (17, 'A student takes Quiz 4 twice and scores lower on the second attempt. Which score counts toward the grade?', '["The higher score is kept","The most recent score is kept","The two scores are averaged","Only the first attempt counts"]', 'The higher score is kept'),
    (18, 'Which statement correctly describes the quizzes in ICT1?', '["There are 7 quizzes; each quiz has 20 items and a 10-minute time limit, taken in a single attempt","There are 7 quizzes; each quiz has 10 items and a 20-minute time limit, taken in multiple attempts","There are 5 quizzes; each quiz has 20 items and a 30-minute time limit, taken in a single attempt","There are 3 quizzes; each quiz has 50 items and a 60-minute time limit, taken in a single attempt"]', 'There are 7 quizzes; each quiz has 20 items and a 10-minute time limit, taken in a single attempt'),
    (19, 'Where does each ICT1 quiz draw its source material from?', '["The slide deck of the quiz week, attached to the quiz","A reviewer handout sold at the campus bookstore","The personal lecture notes of the instructor, never shared with students","A random question bank unrelated to the weekly topics"]', 'The slide deck of the quiz week, attached to the quiz'),
    (20, 'Which statement correctly describes the PRELIM and FINAL examinations in ICT1?', '["PRELIM: coverage Weeks 1–7, 60 minutes. FINAL: coverage Weeks 1–7, 100 items, 60 minutes","PRELIM: coverage Weeks 1–3, 60 minutes. FINAL: coverage Weeks 4–7, 100 items, 120 minutes","PRELIM: coverage Weeks 1–7, 100 items, 60 minutes. FINAL: coverage Weeks 1–7, 60 minutes","PRELIM: coverage Weeks 1–7, 30 minutes. FINAL: coverage Weeks 1–7, 50 items, 30 minutes"]', 'PRELIM: coverage Weeks 1–7, 60 minutes. FINAL: coverage Weeks 1–7, 100 items, 60 minutes')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz1_week1_orientation: Quiz 1 (%) now has 20 orientation-based questions', v_quiz;
END $$;
