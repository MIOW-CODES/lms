-- Course: ICT1 … Quiz 1 — Week 2 (Slide: WEEK 2 Productivity Tools in Education MS Word • Google Docs)
--
-- ICT1 Quiz 1 — 10 multiple-choice questions grounded strictly in the Week 2
-- lecture slides "Productivity Tools in Education" (MS Word / Google Docs).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If missing: NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 1' exists on ICT1: keep the quiz row, hard
--     delete its old quiz_questions rows, insert this slide-based set.
--   * Otherwise: insert the quiz + its questions.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_quiz1_week2_productivity: course code ICT1 not found — skipping Quiz 1';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 1' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 1', 15, 10, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 15, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz1_week2_productivity: Quiz 1 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz1_week2_productivity: created Quiz 1 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 2, what is productivity software?', '["Applications designed to help you create, organize, and manage everyday teaching tasks","A type of classroom hardware for teachers","Software used only for making slide decks","An operating system used in the computer lab"]', 'Applications designed to help you create, organize, and manage everyday teaching tasks'),
    (2,  'Which everyday teaching tasks are word processors used for?', '["Lesson plans, letters, worksheets","Grade sheets, records, charts","Slide decks for instruction","Email and file storage"]', 'Lesson plans, letters, worksheets'),
    (3,  'A teacher wants to make sure a lesson plan is never lost if a device fails. What does Week 2 recommend?', '["Store files in Google Drive or OneDrive","Keep the only copy on the classroom desktop","Print a copy and discard the digital file","Save the file in the LMS only"]', 'Store files in Google Drive or OneDrive'),
    (4,  'How do reusable lesson plan templates help teachers?', '["They save prep time every week","They replace the need for learning objectives","They grade student work automatically","They make the lesson plan longer"]', 'They save prep time every week'),
    (5,  'What should the header of a lesson plan document include?', '["Subject, grade level, date, and duration","Only the teacher''s name and the school","The full procedure and assessment","The title and the table of contents"]', 'Subject, grade level, date, and duration'),
    (6,  'Learning objectives in a lesson plan should be stated', '["Clearly and measurably","As loosely as possible","Only in the document header","After the assessment section"]', 'Clearly and measurably'),
    (7,  'The Procedure section of a lesson plan covers', '["Introduction, activities, and closure","Subject, grade level, date, and duration","Materials and resources only","How student learning will be checked"]', 'Introduction, activities, and closure'),
    (8,  'A student manually bolds and resizes each section title instead of using Styles (Heading 1/2). Why is that a problem?', '["The document will not stay consistent, and a table of contents cannot be made later","The document can no longer be shared through the cloud","Comments can no longer be added to the document","The lesson plan will be missing its header"]', 'The document will not stay consistent, and a table of contents cannot be made later'),
    (9,  'While reviewing a colleague''s lesson plan, you want to suggest changes. What does Week 2 recommend?', '["Add comments rather than changing their text directly","Rewrite their text directly to save time","Print the plan and mark it in red ink","Email the changes instead of using comments"]', 'Add comments rather than changing their text directly'),
    (10, 'For this week''s Output-Based Activity, what must the submitted lesson plan include?', '["Header, objectives, materials, procedure, and assessment sections","Header and objectives only","A title page and a bibliography only","Procedure and closure only"]', 'Header, objectives, materials, procedure, and assessment sections')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz1_week2_productivity: Quiz 1 (%) now has 10 slide-based questions', v_quiz;
END $$;
