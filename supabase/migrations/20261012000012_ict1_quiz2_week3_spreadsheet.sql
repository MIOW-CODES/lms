-- Course: ICT1 … Quiz 2 — Week 3 (Slide: WEEK 3 Spreadsheet Applications ICT 1 — Creating grade sheets and charts for classroom use MS Excel • Google Sheets)
--
-- ICT1 Quiz 2 — 10 multiple-choice questions grounded strictly in the Week 3
-- lecture slides "Spreadsheet Applications" (MS Excel / Google Sheets).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If missing: NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 2' exists on ICT1: keep the quiz row, hard
--     delete its old quiz_questions rows, insert this slide-based set.
--   * Otherwise: insert the quiz + its questions.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_quiz2_week3_spreadsheet: course code ICT1 not found — skipping Quiz 2';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 2' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 2', 15, 10, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 15, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz2_week3_spreadsheet: Quiz 2 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz2_week3_spreadsheet: created Quiz 2 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'In spreadsheet basics, what is a cell?', '["A single box where data or a formula lives","A full grid of cells within a workbook","A line of data running across the sheet","A chart drawn from student scores"]', 'A single box where data or a formula lives'),
    (2,  'In a spreadsheet, how do rows and columns run?', '["Rows run across; columns run down","Rows run down; columns run across","Both rows and columns run across","Both rows and columns run down"]', 'Rows run across; columns run down'),
    (3,  'What is a sheet in a spreadsheet workbook?', '["A full grid of cells within a workbook","A single box where a formula lives","A column of assignment scores","A chart type for grade distributions"]', 'A full grid of cells within a workbook'),
    (4,  'Which function adds up scores across an assignment or a whole quarter?', '["SUM","AVERAGE","SORT","FILTER"]', 'SUM'),
    (5,  'Which function calculates a student''s overall grade from multiple scores?', '["AVERAGE","SUM","FILTER","SORT"]', 'AVERAGE'),
    (6,  'A teacher wants to see only the students who are below passing. Which feature should be used?', '["FILTER","AVERAGE","SUM","Freeze the top row"]', 'FILTER'),
    (7,  'In the class grade sheet demonstration, the Total column is added using', '["=SUM() across each row","=AVERAGE() across each column","Manual math on a calculator","A bar or column chart"]', '=SUM() across each row'),
    (8,  'What happens when you drag the fill handle after entering a formula?', '["The formula is copied down the column automatically","The column headers are formatted in bold","The top row is frozen for easy scrolling","The data is turned into a chart"]', 'The formula is copied down the column automatically'),
    (9,  'Which chart is best for tracking a student''s progress across the term?', '["Line Chart","Bar / Column Chart","Pie Chart","Table"]', 'Line Chart'),
    (10, 'For the Week 3 performance task, the grade sheet''s Total and Average columns must use', '["Formulas, not manual math","Manual math only","Charts, not formulas","Values typed in from a calculator"]', 'Formulas, not manual math')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz2_week3_spreadsheet: Quiz 2 (%) now has 10 slide-based questions', v_quiz;
END $$;
