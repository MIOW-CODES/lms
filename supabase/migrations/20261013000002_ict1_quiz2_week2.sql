-- Course: ICT1 — Quiz 2 — Week 2 (Slide: The Teacher as a Professional)
--
-- ICT1 Quiz 2 — 10 multiple-choice questions grounded strictly in the Week 2
-- lecture slides "The Teacher as a Professional" (teacher identity, professional
-- ethics, competencies, and the many roles of a TVET teacher).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 2' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz2_week2: course code ICT1 not found — skipping Quiz 2';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 2' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 2', 20, 10, NULL::timestamptz, now() + interval '14 days', false, false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 2' AND deleted_at IS NULL
  )
  RETURNING id INTO v_quiz;

  IF v_quiz IS NULL THEN
    -- Quiz already exists: replace its question set in place.
    SELECT id INTO v_quiz FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 2' AND deleted_at IS NULL
     ORDER BY created_at
     LIMIT 1;
    DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;
    UPDATE public.quizzes SET duration_minutes = 20, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz2_week2: Quiz 2 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz2_week2: created Quiz 2 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 2, what is professional identity?', '["How a TVET teacher understands their own role, values, and purpose","The list of diplomas and certificates a teacher has earned","The teacher''s annual performance rating from the supervisor","The rules the school posts on its walls"]', 'How a TVET teacher understands their own role, values, and purpose'),
    (2,  'Which pillar of teacher identity means seeing oneself as a partner in the community''s development, not just a classroom instructor?', '["Community Orientation","Technical Mastery","Pedagogical Skill","Professional Ethics"]', 'Community Orientation'),
    (3,  'A TVET teacher guides hands-on, competency-based learning rather than simply lecturing. Which role does this describe?', '["Facilitator","Mentor","Leader","Community Partner"]', 'Facilitator'),
    (4,  'A teacher coaches learners through skills development, confidence, and career readiness. Which role is this?', '["Mentor","Facilitator","Leader","Community Partner"]', 'Mentor'),
    (5,  'A TVET teacher models professionalism and sets direction within the training institution. Which role is this?', '["Leader","Facilitator","Mentor","Community Partner"]', 'Leader'),
    (6,  'Which professional ethic means being honest and consistent in teaching, assessment, and dealings with learners and colleagues?', '["Integrity","Fairness","Accountability","Respect"]', 'Integrity'),
    (7,  'Which professional ethic means applying standards and grading competencies equitably, without bias or favoritism?', '["Fairness","Integrity","Continuous Improvement","Respect"]', 'Fairness'),
    (8,  'What does competency-based TVET measure?', '["What a learner can actually do against a defined standard — not seat time","How many hours a learner spent in the training hall","How well a learner memorizes lecture notes","The learner''s ranking against classmates"]', 'What a learner can actually do against a defined standard — not seat time'),
    (9,  'Which competency type covers core work-readiness skills — communication, teamwork, safety, and professionalism?', '["Basic Competencies","Common Competencies","Core / Technical Competencies","Training Methodology"]', 'Basic Competencies'),
    (10, 'A newly hired TVET teacher wants their own training competencies formally certified. Which framework does Week 2 cite?', '["The TESDA Trainers-Assessors qualification","A CHED faculty ranking manual","The basic education curriculum guide of DepEd","The annual performance evaluation of the school"]', 'The TESDA Trainers-Assessors qualification')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz2_week2: Quiz 2 (%) now has 10 slide-based questions', v_quiz;
END $$;
