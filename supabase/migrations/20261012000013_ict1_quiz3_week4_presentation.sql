-- Course: ICT1 … Quiz 3 — Week 4 (Slide: WEEK 4 Presentation Tools ICT 1 - Designing instructional presentations that teach clearly PowerPoint • Google Slides)
--
-- ICT1 Quiz 3 — 10 multiple-choice questions grounded strictly in the Week 4
-- lecture slides "Presentation Tools" (PowerPoint / Google Slides).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If missing: NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 3' exists on ICT1: keep the quiz row, hard
--     delete its old quiz_questions rows, insert this slide-based set.
--   * Otherwise: insert the quiz + its questions.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_quiz3_week4_presentation: course code ICT1 not found — skipping Quiz 3';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 3' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 3', 15, 10, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 15, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz3_week4_presentation: Quiz 3 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz3_week4_presentation: created Quiz 3 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What is the problem with a cluttered slide?', '["It competes with your voice instead of supporting it","It helps students absorb ideas faster","It makes the presentation shorter","It keeps students listening instead of reading"]', 'It competes with your voice instead of supporting it'),
    (2,  'What does a clear slide contain?', '["One idea, a short phrase, and a supporting image","Dense paragraphs and tiny text","Five colors and a busy background","Full sentences for students to read aloud"]', 'One idea, a short phrase, and a supporting image'),
    (3,  'Slides should be thought of as', '["Visual support for your teaching, not a script to read aloud","A script to read aloud to the class","A complete record of the whole lesson","A place for full paragraphs of notes"]', 'Visual support for your teaching, not a script to read aloud'),
    (4,  'According to the "One Idea Per Slide" principle, each slide should', '["Make a single clear point, not several at once","Cover several points at the same time","Contain full paragraphs of text","Duplicate the lecture script"]', 'Make a single clear point, not several at once'),
    (5,  'For consistent color and font, Week 4 recommends', '["One palette and one or two fonts, used throughout","A different palette and font for every slide","Five colors and as many fonts as possible","Random fonts chosen per slide for variety"]', 'One palette and one or two fonts, used throughout'),
    (6,  'Why use visuals instead of walls of text on a slide?', '["Images, icons, and diagrams communicate faster than paragraphs","Text walls make the slide look more professional","Visuals allow you to remove the slide title","Students prefer reading dense text"]', 'Images, icons, and diagrams communicate faster than paragraphs'),
    (7,  'What does "visual hierarchy" mean on a slide?', '["Titles, subpoints, and body text are sized to show what matters most","Every line of text is the same size","The slide uses as many colors as possible","Images are placed behind busy backgrounds"]', 'Titles, subpoints, and body text are sized to show what matters most'),
    (8,  'Why does the instructor use the Slide Master when building a deck?', '["It updates fonts and colors across the whole deck at once","It adds animation to every slide automatically","It converts the deck into a Word document","It prints handouts for the class"]', 'It updates fonts and colors across the whole deck at once'),
    (9,  'You are presenting and a chart appears on the screen. What does Week 4 recommend?', '["Pause and give students a moment to look at it before you speak over it","Talk over the chart as quickly as possible","Turn your back to the class and read the chart aloud","Skip past the chart to keep the presentation moving"]', 'Pause and give students a moment to look at it before you speak over it'),
    (10, 'What is the Week 4 rubric-based output?', '["A 3–5 slide instructional deck on a topic of your choice","A one-page lesson plan in Word or Google Docs","A class grade sheet with a chart","A 20-slide research report"]', 'A 3–5 slide instructional deck on a topic of your choice')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz3_week4_presentation: Quiz 3 (%) now has 10 slide-based questions', v_quiz;
END $$;
