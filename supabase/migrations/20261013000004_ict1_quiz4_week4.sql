-- Course: ICT1 — Quiz 4 — Week 4 (Slide: Understanding School Culture)
--
-- ICT1 Quiz 4 — 10 multiple-choice questions grounded strictly in the Week 4
-- lecture slides "Understanding School Culture" (definition, three levels of
-- culture, five dimensions, visible vs. invisible culture, and why culture
-- matters in TVET).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 4' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz4_week4: course code ICT1 not found — skipping Quiz 4';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 4' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 4', 20, 10, NULL::timestamptz, now() + interval '14 days', false, false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 4' AND deleted_at IS NULL
  )
  RETURNING id INTO v_quiz;

  IF v_quiz IS NULL THEN
    -- Quiz already exists: replace its question set in place.
    SELECT id INTO v_quiz FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 4' AND deleted_at IS NULL
     ORDER BY created_at
     LIMIT 1;
    DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;
    UPDATE public.quizzes SET duration_minutes = 20, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz4_week4: Quiz 4 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz4_week4: created Quiz 4 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 4, what is school culture?', '["The shared set of norms, values, beliefs, traditions, and practices that shape how people in a school think, feel, and act","The written policies and official documents issued by the school administration","The physical facilities, equipment, and workshop layout of the school","The personal attitude of an individual teacher"]', 'The shared set of norms, values, beliefs, traditions, and practices that shape how people in a school think, feel, and act'),
    (2,  'School culture is often described as', '["“The way things are done around here”","“What the mission statement says”","“What the school handbook prescribes”","“How the principal runs the office”"]', '“The way things are done around here”'),
    (3,  'The building, uniforms, ceremonies, posted rules, and how people greet each other belong to which level of culture?', '["Artifacts — what you can see and hear","Espoused Values — what the school says it stands for","Underlying Assumptions — the unspoken level","Practices — the routine, everyday ways of doing work"]', 'Artifacts — what you can see and hear'),
    (4,  'A school''s mission statements, codes of conduct, and publicly declared priorities belong to which level of culture?', '["Espoused Values — what the school says it stands for","Artifacts — what you can see and hear","Underlying Assumptions — the unspoken level","Traditions — recurring events and rituals"]', 'Espoused Values — what the school says it stands for'),
    (5,  'Deeply held, often unconscious beliefs that truly drive behavior belong to which level of culture?', '["Underlying Assumptions — the unspoken level","Artifacts — what you can see and hear","Espoused Values — what the school says it stands for","Norms — the unwritten rules of behavior"]', 'Underlying Assumptions — the unspoken level'),
    (6,  'Which dimension of school culture refers to the unwritten rules for how people are expected to behave and interact?', '["Norms","Values","Traditions","Practices"]', 'Norms'),
    (7,  'Recurring events and rituals that reinforce a sense of identity and belonging are which dimension of school culture?', '["Traditions","Norms","Beliefs","Practices"]', 'Traditions'),
    (8,  'What the school community collectively considers important or worthwhile is which dimension of school culture?', '["Values","Norms","Beliefs","Traditions"]', 'Values'),
    (9,  'Trainers stay longer where they feel valued, supported, and part of a shared mission. Why does school culture matter in TVET here?', '["Staff Retention","Learning Quality","Industry Trust","Change Readiness"]', 'Staff Retention'),
    (10, 'Unspoken assumptions about learner potential and trust (or distrust) between staff and leadership are examples of', '["Invisible culture","Visible culture","Espoused values","Posted school policies"]', 'Invisible culture')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz4_week4: Quiz 4 (%) now has 10 slide-based questions', v_quiz;
END $$;
