-- Course: ICT1 — Quiz 3 — Week 3 (Slide: Spreadsheet Applications — Creating Grade Sheets and Charts for Classroom Use)
--
-- ICT1 Quiz 3 — 20 multiple-choice questions grounded strictly in the Week 3
-- lecture slides "Spreadsheet Applications" (MS Excel / Google Sheets).
-- 10-minute knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 3' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz3_week3_spreadsheets: course code ICT1 not found — skipping Quiz 3';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 3' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 3', 10, 20, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 10, question_count = 20 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz3_week3_spreadsheets: Quiz 3 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz3_week3_spreadsheets: created Quiz 3 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'Which tools does Week 3 use for creating grade sheets and charts for classroom use?', '["MS Excel and Google Sheets","PowerPoint and Google Slides","Gmail and Google Drive","MS Word and Google Docs"]', 'MS Excel and Google Sheets'),
    (2,  'What is the stated learning outcome for Week 3?', '["Create simple grade sheets and charts","Design instructional presentations that teach clearly","Build a learning management system course","Troubleshoot computer hardware components"]', 'Create simple grade sheets and charts'),
    (3,  'Which assessment tool is used in Week 3?', '["Performance Task, graded on the completed grade sheet and chart built in class","A written multiple-choice midterm examination","A research paper on the history of spreadsheets","A group debate on chart types"]', 'Performance Task, graded on the completed grade sheet and chart built in class'),
    (4,  'According to Week 3, what does a spreadsheet do?', '["It organizes information into a grid so it can be calculated, sorted, and visualized quickly","It stores files in the cloud so they can be shared by email","It displays slides in sequence for an audience","It records macros that install software automatically"]', 'It organizes information into a grid so it can be calculated, sorted, and visualized quickly'),
    (5,  'In spreadsheet basics, what is a cell?', '["A single box where data or a formula lives","A full grid of cells within a workbook","A line of text at the top of the screen","A folder that stores spreadsheet files"]', 'A single box where data or a formula lives'),
    (6,  'How do rows and columns run in a spreadsheet?', '["Rows run across; columns run down","Rows run down; columns run across","Both rows and columns run across","Rows and columns exist only in charts"]', 'Rows run across; columns run down'),
    (7,  'What is a sheet in spreadsheet terminology?', '["A full grid of cells within a workbook","A single box where data or a formula lives","A chart embedded inside a cell","A printout of the grade book"]', 'A full grid of cells within a workbook'),
    (8,  'What does the SUM function do in a grade sheet?', '["It adds up scores across an assignment or a whole quarter","It calculates a student''s overall grade from multiple scores","It arranges students by name, score, or ranking instantly","It shows only the rows you need"]', 'It adds up scores across an assignment or a whole quarter'),
    (9,  'What does the AVERAGE function calculate for grading?', '["A student''s overall grade from multiple scores","The total points of the whole class","The number of students below passing","The ranking of students by name"]', 'A student''s overall grade from multiple scores'),
    (10, 'Which function arranges students by name, score, or ranking instantly?', '["SORT","SUM","AVERAGE","FILTER"]', 'SORT'),
    (11, 'A teacher wants to see only the students who are below passing in the grade sheet. Which feature should she use?', '["FILTER, which shows only the rows you need","SUM, which adds up scores across an assignment","AVERAGE, which computes the term grade","A pie chart, which shows grade distribution"]', 'FILTER, which shows only the rows you need'),
    (12, 'What is the first step when building a class grade sheet?', '["Set column headers: student name, then one column per assignment","Add a Total column using =SUM() across each row","Insert a bar or column chart of the class scores","Freeze the top row for easy scrolling"]', 'Set column headers: student name, then one column per assignment'),
    (13, 'The performance task requires Total and Average columns built with formulas, not manual math. Which formula builds the Total column?', '["=SUM() across each row","=AVERAGE() for the term grade","=SORT() across each column","=FILTER() for students below passing"]', '=SUM() across each row'),
    (14, 'What is the Average column used for in the class grade sheet?', '["Computing the term grade using =AVERAGE()","Adding up scores across a whole quarter with =SUM()","Arranging students by ranking with SORT","Freezing the top row for easy scrolling"]', 'Computing the term grade using =AVERAGE()'),
    (15, 'Why does the demonstration format headers in bold and freeze the top row?', '["For easy scrolling through the grade sheet","So the formulas calculate faster","To release scores to students automatically","To convert the sheet into a pie chart"]', 'For easy scrolling through the grade sheet'),
    (16, 'What happens when you drag the fill handle down a column?', '["It copies the formula down the column automatically, avoiding retyping the same formula for every student","It deletes the formula from every row except the first","It converts the grade sheet into a bar chart","It sorts the students by name instantly"]', 'It copies the formula down the column automatically, avoiding retyping the same formula for every student'),
    (17, 'Which chart is best for comparing scores across students or assignments?', '["Bar / column chart","Line chart","Pie chart","Slide layout"]', 'Bar / column chart'),
    (18, 'A teacher wants to track one student''s progress across the term. Which chart is best?', '["Line chart","Bar / column chart","Pie chart","Filter view"]', 'Line chart'),
    (19, 'Which chart is best for showing proportions, like a grade distribution?', '["Pie chart","Bar / column chart","Line chart","Fill handle chart"]', 'Pie chart'),
    (20, 'How must the Week 3 performance task be submitted?', '["Share the sheet link or upload the file through the LMS before class ends","Email it to the instructor a week later","Print it and hand it in during the next meeting","Post it on social media"]', 'Share the sheet link or upload the file through the LMS before class ends')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz3_week3_spreadsheets: Quiz 3 (%) now has 20 slide-based questions', v_quiz;
END $$;
