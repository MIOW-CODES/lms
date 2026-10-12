-- Course: ICT1 — Quiz 4 — Week 4 (Slide: Presentation Tools — Designing Instructional Presentations That Teach Clearly)
--
-- ICT1 Quiz 4 — 20 multiple-choice questions grounded strictly in the Week 4
-- lecture slides "Presentation Tools" (PowerPoint / Google Slides).
-- 10-minute knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 4' exists on ICT1: keep the quiz row and
--     its availability/release state, hard delete its old quiz_questions rows,
--     insert this slide-based set, refresh duration_minutes = 10 and
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
    RAISE NOTICE 'ict1_quiz4_week4_presentations: course code ICT1 not found — skipping Quiz 4';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 4' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 4', 10, 20, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 10, question_count = 20 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz4_week4_presentations: Quiz 4 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz4_week4_presentations: created Quiz 4 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'Which tools does Week 4 use for designing instructional presentations?', '["PowerPoint and Google Slides","MS Excel and Google Sheets","Gmail and Google Drive","MS Word and Google Docs"]', 'PowerPoint and Google Slides'),
    (2,  'What is the stated learning outcome for Week 4?', '["Design instructional presentations that support teaching","Create simple grade sheets and charts","Assemble computer hardware components","Manage a school''s learning management system"]', 'Design instructional presentations that support teaching'),
    (3,  'Which assessment tool is used in Week 4?', '["Rubric-Based Output, graded on the instructional slide deck created in class","A written multiple-choice midterm examination","A spreadsheet performance task with charts","A peer-evaluated oral debate"]', 'Rubric-Based Output, graded on the instructional slide deck created in class'),
    (4,  'According to Week 4, what does a well-designed slide do?', '["It helps students absorb ideas","It competes with the teacher''s voice","It gives students a full script to read","It replaces the teacher during the lesson"]', 'It helps students absorb ideas'),
    (5,  'What happens when a slide is cluttered — dense paragraphs, tiny text, five colors, and a busy background?', '["Students read instead of listen","Students listen while the slide reinforces the point","Students absorb ideas faster","Transitions between slides feel natural"]', 'Students read instead of listen'),
    (6,  'What does a clear slide contain?', '["One idea, a short phrase, and a supporting image","Dense paragraphs, tiny text, five colors, and a busy background","Full sentences copied from the textbook","Several ideas presented at once"]', 'One idea, a short phrase, and a supporting image'),
    (7,  'How should slides be regarded during teaching?', '["As visual support for your teaching, not a script to read aloud","As a script to read aloud word for word","As a replacement for the teacher''s voice","As a document for students to read silently"]', 'As visual support for your teaching, not a script to read aloud'),
    (8,  'What does the "One Idea Per Slide" principle mean?', '["Each slide should make a single clear point, not several at once","Each slide should carry as many points as will fit","The whole lesson should fit on one screen","Titles should be omitted to save space"]', 'Each slide should make a single clear point, not several at once'),
    (9,  'What does "Consistent Color & Font" recommend?', '["Pick one palette and one or two fonts, and use them throughout","Use a different font on every slide","Use five colors per slide","Match colors to the background image"]', 'Pick one palette and one or two fonts, and use them throughout'),
    (10, 'Why should a slide use visuals instead of walls of text?', '["Images, icons, and diagrams communicate faster than paragraphs","Dense paragraphs communicate faster than images","Decorative backgrounds should fill empty space","Text should be trimmed to full sentences"]', 'Images, icons, and diagrams communicate faster than paragraphs'),
    (11, 'What is visual hierarchy on a slide?', '["Titles, subpoints, and body text sized to show what matters most","All text set in the same size","Body text larger than titles","Fonts chosen randomly on each slide"]', 'Titles, subpoints, and body text sized to show what matters most'),
    (12, 'What is the first step when building an instructional slide?', '["Start with a layout: title-only, title-and-content, or two-column","Write the full script of the lesson on the slide","Add a decorative busy background","Open the Slide Master"]', 'Start with a layout: title-only, title-and-content, or two-column'),
    (13, 'How should the title of an instructional slide be written?', '["As a short, specific title stating the slide''s one idea","As a long paragraph introducing the topic","As the full sentence of the lesson objective","As the date and section only"]', 'As a short, specific title stating the slide''s one idea'),
    (14, 'What visual should be added to an instructional slide?', '["A supporting image, icon, or simple chart — not decoration","A busy background image","Five colors of clip art","A wall of text"]', 'A supporting image, icon, or simple chart — not decoration'),
    (15, 'How should text on an instructional slide be trimmed?', '["To keywords or short phrases, not full sentences","To full sentences copied from the textbook","To dense paragraphs","To the full script read aloud"]', 'To keywords or short phrases, not full sentences'),
    (16, 'What does the Slide Master do in the demonstration?', '["It updates fonts and colors across the whole deck at once","It records the presentation as a video","It exports the deck to the LMS","It adds a chart to a single slide"]', 'It updates fonts and colors across the whole deck at once'),
    (17, 'What does "Practice the Flow" mean for delivery?', '["Rehearse moving between slides so transitions feel natural, not rushed","Read every slide aloud word for word","Turn your back to the class","Speak over a chart immediately"]', 'Rehearse moving between slides so transitions feel natural, not rushed'),
    (18, 'Why should you face the class, not the screen?', '["The slide is a prompt for you — don''t turn your back to read it","The screen hides the slide content","Students cannot see the projector","The slide should be read aloud by students"]', 'The slide is a prompt for you — don''t turn your back to read it'),
    (19, 'What does "Pause on Visuals" advise?', '["Give students a moment to look at a chart or image before you speak over it","Speak over the chart as soon as it appears","Skip charts to save class time","Hide visuals until the end of the lesson"]', 'Give students a moment to look at a chart or image before you speak over it'),
    (20, 'What must be submitted for the Week 4 rubric-based output?', '["A 3–5 slide instructional deck, shared as a link or uploaded through the LMS before class ends","A written essay on slide design submitted a week later","A spreadsheet grade sheet with charts","A 20-slide deck of dense paragraphs"]', 'A 3–5 slide instructional deck, shared as a link or uploaded through the LMS before class ends')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz4_week4_presentations: Quiz 4 (%) now has 20 slide-based questions', v_quiz;
END $$;
