-- Course: ICT1 — Quiz 3 — Week 3 (Slide: The Teacher and the Community)
--
-- ICT1 Quiz 3 — 10 multiple-choice questions grounded strictly in the Week 3
-- lecture slides "The Teacher and the Community" (school-community
-- relationships, community needs, social responsibility, and community
-- participation).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 3' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz3_week3: course code ICT1 not found — skipping Quiz 3';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 3' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 3', 20, 10, NULL::timestamptz, now() + interval '14 days', false, false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 3' AND deleted_at IS NULL
  )
  RETURNING id INTO v_quiz;

  IF v_quiz IS NULL THEN
    -- Quiz already exists: replace its question set in place.
    SELECT id INTO v_quiz FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 3' AND deleted_at IS NULL
     ORDER BY created_at
     LIMIT 1;
    DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;
    UPDATE public.quizzes SET duration_minutes = 20, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz3_week3: Quiz 3 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz3_week3: created Quiz 3 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 3, how does a TVET school relate to the community it serves?', '["Through an ongoing, two-way relationship","By operating in isolation from local concerns","Through a one-way relationship where the school only issues announcements","By depending entirely on national government directives"]', 'Through an ongoing, two-way relationship'),
    (2,  'Which of the following does the community give to the school?', '["Real-world context, industry needs, and feedback that keeps training relevant","Trained, work-ready graduates","A venue for community learning and events","Technical expertise and consultation"]', 'Real-world context, industry needs, and feedback that keeps training relevant'),
    (3,  'A teacher speaks up for the learners'' and the community''s interests within the institution. Which community-leader role is this?', '["Advocate","Bridge","Model","Resource"]', 'Advocate'),
    (4,  'A teacher shares technical knowledge and skills to support community initiatives. Which community-leader role is this?', '["Resource","Bridge","Advocate","Model"]', 'Resource'),
    (5,  'When should a community needs assessment be conducted?', '["Before designing programs or outreach, not after","After the outreach program has been implemented","Only when the school loses its industry partners","Once every five years during accreditation"]', 'Before designing programs or outreach, not after'),
    (6,  'What is the first step in understanding community needs?', '["Gather Data — collect information on local demographics, industries, employment gaps, and learner backgrounds","Set Priorities — translate findings into realistic, actionable priorities","Engage Stakeholders — talk with local employers, LGUs, parents, and learners","Identify Gaps — compare current programs and services against what the community needs"]', 'Gather Data — collect information on local demographics, industries, employment gaps, and learner backgrounds'),
    (7,  'A school talks with local employers, LGUs, parents, and learners about their priorities. Which step in understanding community needs is this?', '["Engage Stakeholders","Gather Data","Identify Gaps","Set Priorities"]', 'Engage Stakeholders'),
    (8,  'Advocating so training opportunities reach marginalized and underserved learners is part of which dimension of the teacher''s social responsibility?', '["Equitable Access","Ethical Influence","Local Development","Sustainability"]', 'Equitable Access'),
    (9,  'At which level of community participation do the school and community co-design programs and share decision-making?', '["Collaborate","Consult","Involve","Inform"]', 'Collaborate'),
    (10, 'In a barangay livelihood program, the community leads the initiative and the school supports their efforts. Which level of community participation is this?', '["Empower","Collaborate","Involve","Inform"]', 'Empower')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz3_week3: Quiz 3 (%) now has 10 slide-based questions', v_quiz;
END $$;
