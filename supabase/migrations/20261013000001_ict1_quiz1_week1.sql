-- Course: ICT1 — Quiz 1 — Week 1 (Slide: Introduction to the Course and the Philippine TVET System)
--
-- ICT1 Quiz 1 — 10 multiple-choice questions grounded strictly in the Week 1
-- lecture slides "Introduction to the Course and the Philippine TVET System".
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 1' exists on ICT1: keep the quiz row and
--     its availability/release state, hard delete its old quiz_questions rows,
--     insert this slide-based set, refresh duration_minutes = 20 and
--     question_count = 10.
--   * Otherwise: insert the quiz row (opens_at NULL, closes_at now() + 14 days,
--     score_released / answer_key_released false) plus its questions.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_quiz1_week1: course code ICT1 not found — skipping Quiz 1';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 1' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 1', 20, 10, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 20, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz1_week1: Quiz 1 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz1_week1: created Quiz 1 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 1, what is TVET?', '["Education and training that develops occupational skills and competencies for specific trades, crafts, and technical careers","A broad, theory-oriented curriculum that prepares learners for academic degrees","A teacher licensure examination for higher education instructors","A DepEd program focused only on general knowledge and cognitive skills"]', 'Education and training that develops occupational skills and competencies for specific trades, crafts, and technical careers'),
    (2,  'Which curriculum does technical-vocational education use?', '["A competency-based, skills-oriented curriculum","A broad, theory-oriented curriculum","A research-oriented curriculum for higher education","An elective curriculum with no defined standards"]', 'A competency-based, skills-oriented curriculum'),
    (3,  'What does technical-vocational education typically culminate in?', '["National Certificates (NC) via TESDA","Academic degrees from CHED-governed institutions","A Professional Regulation Commission license","A Senior High School diploma from DepEd"]', 'National Certificates (NC) via TESDA'),
    (4,  'In the trifocalized Philippine education system, which agency governs basic education — Kindergarten through Senior High School?', '["DepEd — Department of Education","CHED — Commission on Higher Education","TESDA — Technical Education and Skills Development Authority","Local Government Units (LGUs)"]', 'DepEd — Department of Education'),
    (5,  'Which agency governs degree-granting higher education institutions and programs?', '["CHED — Commission on Higher Education","DepEd — Department of Education","TESDA — Technical Education and Skills Development Authority","Technical-Vocational Institutions (TVIs)"]', 'CHED — Commission on Higher Education'),
    (6,  'Which statement describes the mandate of TESDA?', '["It governs technical-vocational education, training, and skills certification","It governs basic education from Kindergarten through Senior High School","It governs degree-granting higher education institutions and programs","It administers the bar and board examinations nationwide"]', 'It governs technical-vocational education, training, and skills certification'),
    (7,  'What is the legal basis of TESDA?', '["Republic Act No. 7796, the Technical Education and Skills Development Act of 1994","Republic Act No. 10533, the Enhanced Basic Education Act","Republic Act No. 10931, the Universal Access to Quality Tertiary Education Act","There is no law — TESDA operates by tradition only"]', 'Republic Act No. 7796, the Technical Education and Skills Development Act of 1994'),
    (8,  'TESDA formulates competency standards and training regulations for TVET programs. Which TESDA role does this illustrate?', '["Standards Setting","Program Registration","Assessment and Certification","Direct Training Provision"]', 'Standards Setting'),
    (9,  'A local business hosts OJT placements and hires TVET graduates. To which key TVET stakeholder group does it belong?', '["Industry Partners and Employers","NGOs and Professional Organizations","The Commission on Higher Education","Local Government Units (LGUs)"]', 'Industry Partners and Employers'),
    (10, 'How is the Week 1 diagnostic activity treated in the course grade?', '["It is formative — a baseline check, not graded for accuracy","It counts as the Midterm Examination","It is graded as a Case Study / Analytical Activity","It is submitted as the Final Project"]', 'It is formative — a baseline check, not graded for accuracy')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz1_week1: Quiz 1 (%) now has 10 slide-based questions', v_quiz;
END $$;
