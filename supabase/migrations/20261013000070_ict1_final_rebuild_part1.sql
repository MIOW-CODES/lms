-- Course: ICT1 — FINAL EXAMINATION (Coverage: Weeks 1-7) — Part 1 (questions 1–50, Weeks 1–4)
--
-- ICT1 FINAL EXAMINATION — Part 1 rebuild: 50 multiple-choice questions grounded
-- strictly in ICT1's own course materials (NO TVE100 content):
--   Week 1 — Orientation (5 items): course ICT 1 – Information Communication 1
--            (ICT1), College 3rd Year B8, Dr. Alan L. Vergara, the Wk2–Wk7
--            roadmap, and the assessment plan (7 quizzes + PRELIM + FINAL).
--   Week 2 — Productivity Tools in Education (MS Word / Google Docs) — 15 items.
--   Week 3 — Spreadsheet Applications (MS Excel / Google Sheets) — 15 items.
--   Week 4 — Presentation Tools (PowerPoint / Google Slides) — 15 items.
-- Style mix: application/scenario-heavy (teacher-in-class situations, tool and
-- deliverable choices) rather than bare definition recall.
-- Knowledge exam only: no lab_task / simulation items, no attachments in SQL.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1', never a hard-coded uuid. If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'FINAL EXAMINATION (Coverage: Weeks 1-7)' exists
--     on ICT1: reuse that quiz row and leave its configuration untouched
--     (duration_minutes, question_count, opens_at, closes_at, and both release
--     flags survive as the teacher set them).
--   * Otherwise: INSERT the quiz row (duration_minutes = 60,
--     question_count = 100, opens_at NULL, closes_at = now() + 14 days,
--     score_released = false, answer_key_released = false).
--   * Question replacement is scoped to this part's range ONLY:
--     DELETE positions 1–50, then insert positions 1..50 (orientation 5,
--     Week 2: 15, Week 3: 15, Week 4: 15 — in that order). Positions 51–100
--     are owned by the Part 2 migration and are never touched here.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
  v_n      int;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_final_rebuild_part1: course code ICT1 not found — skipping FINAL EXAMINATION part 1';
    RETURN;
  END IF;
  RAISE NOTICE 'ict1_final_rebuild_part1: resolved course ICT1 (%)', v_course;

  -- Reuse an existing active FINAL EXAMINATION quiz row (config untouched), else create one.
  SELECT id INTO v_quiz FROM public.quizzes
   WHERE course_id = v_course
     AND title = 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
     AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    INSERT INTO public.quizzes
      (course_id, title, duration_minutes, question_count, opens_at, closes_at,
       score_released, answer_key_released)
    VALUES
      (v_course, 'FINAL EXAMINATION (Coverage: Weeks 1-7)', 60, 100, NULL::timestamptz,
       now() + interval '14 days', false, false)
    RETURNING id INTO v_quiz;
    RAISE NOTICE 'ict1_final_rebuild_part1: created FINAL EXAMINATION quiz (%)', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_final_rebuild_part1: reusing FINAL EXAMINATION quiz (%) — configuration left untouched', v_quiz;
  END IF;

  -- Replace ONLY positions 1–50 (owned by part 1); positions 51–100 untouched.
  DELETE FROM public.quiz_questions
   WHERE quiz_id = v_quiz AND position BETWEEN 1 AND 50;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'ict1_final_rebuild_part1: cleared prior questions in positions 1–50 (% row(s) removed)', v_n;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'On the first day, Dr. Alan L. Vergara opens the ICT1 course for his B8 class. What is the full title of this course?', '["ICT 1 – Information Communication 1","ICT 1 – Introduction to Computers 1","ICT 1 – Internet and Communication Tools 1","ICT 1 – Instructional Computing 1"]', 'ICT 1 – Information Communication 1'),
    (2,  'Which year level and section is the ICT1 class handled by Dr. Alan L. Vergara scheduled for?', '["College 3rd Year — B8","College 2nd Year — B8","College 3rd Year — B7","Senior High Grade 12 — B8"]', 'College 3rd Year — B8'),
    (3,  'A student checks the course roadmap to plan ahead. Which topic is scheduled for Week 5 of ICT1?', '["Online Collaboration Tools","Productivity Tools","Presentation Tools","Learning Management System (LMS)"]', 'Online Collaboration Tools'),
    (4,  'In the ICT1 assessment plan, how are the seven quizzes structured?', '["7 quizzes, 20 items each, answered in 10 minutes","7 quizzes, 10 items each, answered in 20 minutes","7 quizzes, 20 items each, answered in 30 minutes","7 quizzes, 50 items each, answered in 60 minutes"]', '7 quizzes, 20 items each, answered in 10 minutes'),
    (5,  'Which statement correctly describes the two major examinations in ICT1?', '["The PRELIM covers Weeks 1–7 and runs 60 minutes; the FINAL has 100 items in 60 minutes","The PRELIM covers Weeks 1–4 and runs 30 minutes; the FINAL has 50 items in 30 minutes","The PRELIM covers Weeks 5–7 and runs 60 minutes; the FINAL has 100 items in 30 minutes","The PRELIM has 100 items in 30 minutes; the FINAL covers Weeks 1–4 and runs 60 minutes"]', 'The PRELIM covers Weeks 1–7 and runs 60 minutes; the FINAL has 100 items in 60 minutes'),
    (6,  'Ms. Reyes wants to create, organize, and manage her everyday teaching tasks faster and more consistently than by hand. What kind of software does Week 2 recommend?', '["Productivity software — applications designed to help create, organize, and manage everyday teaching tasks","Simulation software — applications designed to replace classroom instruction","Assessment software — applications designed to grade quizzes automatically","Security software — applications designed to protect devices from malware"]', 'Productivity software — applications designed to help create, organize, and manage everyday teaching tasks'),
    (7,  'A teacher needs to write lesson plans, letters, and worksheets. Which productivity tool should she use?', '["A word processor such as MS Word or Google Docs","A spreadsheet such as MS Excel or Google Sheets","A presentation tool such as PowerPoint or Google Slides","An email client such as Gmail"]', 'A word processor such as MS Word or Google Docs'),
    (8,  'A teacher starts every week''s lesson plan from a blank page and runs out of prep time. Which Week 2 best practice would fix this?', '["Build one lesson plan template and reuse it all term","Type the plan again each week so it stays fresh","Write the plan on paper before encoding it","Store the plan only on the classroom desktop computer"]', 'Build one lesson plan template and reuse it all term'),
    (9,  'While reviewing a colleague''s lesson plan, what should a teacher do instead of changing the text directly?', '["Add comments rather than editing their text","Rewrite the weak sections directly","Delete the sections that need improvement","Print the document and mark corrections by hand"]', 'Add comments rather than editing their text'),
    (10, 'A school device suddenly fails, but a teacher''s work survives. Why does Week 2 say this is possible?', '["Google Docs autosaves and syncs across devices, and files kept in Google Drive or OneDrive survive a device failure","The document is printed and filed in the faculty room every day","The file is saved in the device''s Downloads folder","The LMS automatically grades a backup copy of the document"]', 'Google Docs autosaves and syncs across devices, and files kept in Google Drive or OneDrive survive a device failure'),
    (11, 'Which set of sections must a complete one-page lesson plan document contain?', '["Header, learning objectives, materials and resources, procedure, and assessment","Title, table of contents, bibliography, and appendix","Introduction, activities, closure, and answer key","Subject, ranking, grade distribution, and chart"]', 'Header, learning objectives, materials and resources, procedure, and assessment'),
    (12, 'A teacher manually bolds and resizes every heading in her lesson plan. What should she use instead?', '["Styles (Heading 1/2)","A larger font size with italics","A separate text box for each heading","Underline and text highlighting"]', 'Styles (Heading 1/2)'),
    (13, 'Why does the instructor insist on Heading 1/2 styles instead of manually bolding and resizing text?', '["It keeps the document consistent and makes a table of contents possible later","It makes the document look more colorful","It reduces the file size of the document","It prevents other teachers from editing the document"]', 'It keeps the document consistent and makes a table of contents possible later'),
    (14, 'According to the anatomy of a lesson plan, learning objectives must be stated', '["clearly and measurably","in long, detailed paragraphs","as many as possible for the whole term","only after the lesson has been delivered"]', 'clearly and measurably'),
    (15, 'Which parts make up the Procedure section of a lesson plan?', '["Introduction, activities, and closure","Objectives, materials, and assessment","Subject, grade level, and duration","Title, heading styles, and references"]', 'Introduction, activities, and closure'),
    (16, 'What information belongs in the header of a lesson plan document?', '["Subject, grade level, date, and duration","The teacher''s grading rubric and answer key","The list of materials and resources","The procedure''s introduction and closure"]', 'Subject, grade level, date, and duration'),
    (17, 'It is the end of the Week 2 session. What must Ms. Dela Cruz submit as the graded output?', '["A complete one-page lesson plan in Word or Google Docs with header, objectives, materials, procedure, and assessment","A slide deck summarizing the lesson for the class","A grade sheet with Total and Average columns","A reflection paper about productivity software"]', 'A complete one-page lesson plan in Word or Google Docs with header, objectives, materials, procedure, and assessment'),
    (18, 'How is the Week 2 deliverable assessed?', '["Through an Output-Based Activity graded on the completed lesson plan document produced in class","Through a 20-item written quiz on productivity software definitions","Through a rubric-based oral defense of the lesson plan","Through a performance task on building grade sheets and charts"]', 'Through an Output-Based Activity graded on the completed lesson plan document produced in class'),
    (19, 'When and how is the finished lesson plan submitted?', '["The document link is shared or the file is uploaded through the LMS before class ends","It is emailed to the instructor the following week","It is printed and handed in at the next meeting","It is posted on the classroom bulletin board"]', 'The document link is shared or the file is uploaded through the LMS before class ends'),
    (20, 'Which formatting requirement applies to the submitted lesson plan?', '["Heading styles are used consistently, with no manual bold or resize substitutes","All headings must be manually bolded and resized","The document must use five colors and small fonts","Every section must be written in full paragraphs"]', 'Heading styles are used consistently, with no manual bold or resize substitutes'),
    (21, 'A teacher needs to organize class scores into a grid so they can be calculated, sorted, and visualized quickly. Which tool fits this task?', '["A spreadsheet such as MS Excel or Google Sheets","A word processor such as MS Word or Google Docs","A presentation tool such as PowerPoint or Google Slides","An email client such as Gmail"]', 'A spreadsheet such as MS Excel or Google Sheets'),
    (22, 'While building her grade sheet, Ms. Cruz clicks a single box to type a score. What is this box called?', '["A cell","A row","A column","A sheet"]', 'A cell'),
    (23, 'Which statement about the structure of a spreadsheet is correct?', '["Rows run across; columns run down","Rows run down; columns run across","Rows and columns are two names for the same grid lines","Only columns can hold data or formulas"]', 'Rows run across; columns run down'),
    (24, 'In a workbook, what is a sheet?', '["A full grid of cells within a workbook","A single box where data or a formula lives","A chart drawn beside the grade table","A printed copy of the grade sheet"]', 'A full grid of cells within a workbook'),
    (25, 'A teacher wants to add up all of a student''s scores across an assignment and for the whole quarter. Which function should she use?', '["SUM — adds up scores across an assignment or a whole quarter","AVERAGE — calculates a student''s overall grade from multiple scores","SORT — arranges students by name, score, or ranking instantly","FILTER — shows only the rows you need"]', 'SUM — adds up scores across an assignment or a whole quarter'),
    (26, 'Which function calculates a student''s overall grade from multiple scores?', '["AVERAGE — calculates a student''s overall grade from multiple scores","SUM — adds up scores across an assignment or a whole quarter","SORT — arranges students by name, score, or ranking instantly","FILTER — shows only the rows you need"]', 'AVERAGE — calculates a student''s overall grade from multiple scores'),
    (27, 'The teacher wants to arrange the class instantly by name, score, or ranking. Which function helps?', '["SORT — arranges students by name, score, or ranking instantly","FILTER — shows only the rows you need","SUM — adds up scores across an assignment or a whole quarter","AVERAGE — calculates a student''s overall grade from multiple scores"]', 'SORT — arranges students by name, score, or ranking instantly'),
    (28, 'A teacher wants to see only the students who are below passing. Which function should she use?', '["FILTER — shows only the rows you need, e.g. students below passing","SUM — adds up scores across an assignment or a whole quarter","AVERAGE — calculates a student''s overall grade from multiple scores","SORT — arranges students by name, score, or ranking instantly"]', 'FILTER — shows only the rows you need, e.g. students below passing'),
    (29, 'Following the demonstration steps, which formulas build the Total and Average columns of the class grade sheet?', '["=SUM() across each row for the Total column, and =AVERAGE() for the term grade","=AVERAGE() across each row for the Total column, and =SUM() for the term grade","Manual addition and division typed into both columns","=COUNT() across each row for the Total column, and =MAX() for the term grade"]', '=SUM() across each row for the Total column, and =AVERAGE() for the term grade'),
    (30, 'Every student''s row needs the same formula. What does the instructor show so the teacher does not retype it for each student?', '["Dragging the fill handle copies the formula down the column automatically","Copying the formula into every cell one at a time","Typing the formula again for each student","Reopening the file to refresh the formulas"]', 'Dragging the fill handle copies the formula down the column automatically'),
    (31, 'After encoding raw scores, which formatting steps does the demonstration apply to the grade sheet?', '["Format headers in bold and freeze the top row for easy scrolling","Color each student''s row differently and hide the gridlines","Shrink all columns to the minimum width and hide the header row","Convert the header row into a chart and protect the sheet"]', 'Format headers in bold and freeze the top row for easy scrolling'),
    (32, 'Ms. Cruz wants to compare scores across students and assignments. Which chart should she insert?', '["A bar or column chart — best for comparing scores across students or assignments","A line chart — best for tracking a student''s progress across the term","A pie chart — best for showing proportions like a grade distribution","A text table of raw scores with no visualization"]', 'A bar or column chart — best for comparing scores across students or assignments'),
    (33, 'Which chart best tracks one student''s progress across the term?', '["A line chart — best for tracking a student''s progress across the term","A bar or column chart — best for comparing scores across students or assignments","A pie chart — best for showing proportions like a grade distribution","A word cloud of student names"]', 'A line chart — best for tracking a student''s progress across the term'),
    (34, 'A teacher wants to show proportions, such as the class''s grade distribution. Which chart fits best?', '["A pie chart — best for showing proportions like a grade distribution","A bar or column chart — best for comparing scores across students or assignments","A line chart — best for tracking a student''s progress across the term","A blank grid of cells with no chart at all"]', 'A pie chart — best for showing proportions like a grade distribution'),
    (35, 'What must the Week 3 performance task contain to be graded?', '["A grade sheet for a sample class with Total and Average columns built with formulas, not manual math, plus one chart visualizing the class''s scores or grade distribution","Only a hand-written computation of the class average submitted on paper","A slide deck verbally presenting the grade sheet built by someone else","A blank spreadsheet template with no scores encoded"]', 'A grade sheet for a sample class with Total and Average columns built with formulas, not manual math, plus one chart visualizing the class''s scores or grade distribution'),
    (36, 'Which slide matches Week 4''s description of a cluttered slide?', '["Dense paragraphs, tiny text, five colors, and a busy background — students read instead of listen","One idea, a short phrase, and a supporting image — students listen while the slide reinforces the point","A title-only layout presenting a single keyword","A blank slide showing a short question for the class"]', 'Dense paragraphs, tiny text, five colors, and a busy background — students read instead of listen'),
    (37, 'What makes a slide a clear slide according to Week 4?', '["One idea, a short phrase, and a supporting image — students listen while the slide reinforces the point","Dense paragraphs, tiny text, five colors, and a busy background — students read instead of listen","The complete lesson script printed line by line","Five different fonts to highlight every keyword"]', 'One idea, a short phrase, and a supporting image — students listen while the slide reinforces the point'),
    (38, 'According to Week 4, how should teachers think of their slides?', '["As visual support for your teaching, not a script to read aloud","As a complete script of the lecture to be read aloud","As a handout containing every detail of the lesson","As decoration that fills the empty space on the screen"]', 'As visual support for your teaching, not a script to read aloud'),
    (39, 'A teacher crams three different points onto every slide so nothing is forgotten. Which principle of good slide design is she breaking?', '["One idea per slide — each slide should make a single clear point, not several at once","Consistent color and font — one palette and one or two fonts throughout","Use visuals, not walls of text — images communicate faster than paragraphs","Visual hierarchy — sizes should show what matters most"]', 'One idea per slide — each slide should make a single clear point, not several at once'),
    (40, 'The colors and fonts change from slide to slide and the deck looks unprofessional. Which principle fixes this?', '["Consistent color and font — pick one palette and one or two fonts and use them throughout","One idea per slide — each slide should make a single clear point","Visual hierarchy — titles, subpoints, and body text sized to show what matters most","Use visuals, not walls of text — images, icons, and diagrams communicate faster"]', 'Consistent color and font — pick one palette and one or two fonts and use them throughout'),
    (41, 'A slide is covered with long paragraphs that students read while the teacher talks. Which principle should be applied instead?', '["Use visuals, not walls of text — images, icons, and diagrams communicate faster than paragraphs","One idea per slide — each slide should make a single clear point","Consistent color and font — one palette and one or two fonts throughout","Visual hierarchy — titles, subpoints, and body text sized to show what matters most"]', 'Use visuals, not walls of text — images, icons, and diagrams communicate faster than paragraphs'),
    (42, 'Titles, subpoints, and body text are all the same size, so students cannot tell what matters most. Which principle is missing?', '["Visual hierarchy — titles, subpoints, and body text should be sized to show what matters most","One idea per slide — each slide should make a single clear point","Consistent color and font — one palette and one or two fonts throughout","Use visuals, not walls of text — images communicate faster than paragraphs"]', 'Visual hierarchy — titles, subpoints, and body text should be sized to show what matters most'),
    (43, 'What is the first step when the instructor demonstrates building an instructional slide?', '["Start with a layout: title-only, title-and-content, or two-column","Add as many animations as the software allows","Insert the complete lesson script for students to read","Choose five colors for the background"]', 'Start with a layout: title-only, title-and-content, or two-column'),
    (44, 'How should the title of an instructional slide be written?', '["As a short, specific title stating the slide''s one idea","As a full paragraph summarizing the whole lesson","As a single generic word like Introduction","In all capital letters for emphasis"]', 'As a short, specific title stating the slide''s one idea'),
    (45, 'Which image should a teacher add to a content slide?', '["A supporting image, icon, or simple chart — not decoration","A busy background pattern to fill the empty space","A clip-art collage unrelated to the topic","A screenshot of the entire lesson plan document"]', 'A supporting image, icon, or simple chart — not decoration'),
    (46, 'How much text should remain on an instructional slide?', '["Text trimmed to keywords or short phrases, not full sentences","The complete lesson script so students can review it later","At least two full paragraphs per slide","As much text as fits on the slide"]', 'Text trimmed to keywords or short phrases, not full sentences'),
    (47, 'The instructor wants to update fonts and colors across the whole deck at once instead of editing each slide by hand. Which feature does he use?', '["The Slide Master","The spelling checker","The fill handle","The slide transition gallery"]', 'The Slide Master'),
    (48, 'During a class presentation, why should the teacher face the class instead of the screen?', '["The slide is only a prompt for the teacher — turning around to read it loses the class","Because students cannot see the screen otherwise","Because the slide should never be shown to students","Because the presentation cannot advance otherwise"]', 'The slide is only a prompt for the teacher — turning around to read it loses the class'),
    (49, 'A chart appears on the slide during the presentation. What should the teacher do before speaking over it?', '["Pause on visuals — give students a moment to look at the chart or image first","Cover the chart with the pointer and continue speaking","Skip the slide without mentioning it","Read the chart''s data aloud as fast as possible"]', 'Pause on visuals — give students a moment to look at the chart or image first'),
    (50, 'What must the Week 4 rubric-based output contain to be graded well?', '["A 3–5 slide instructional deck with a consistent theme, readable fonts, one clear idea per slide, and at least one relevant image, icon, or chart on each content slide","A 15–20 slide deck with complete lecture notes on every slide","A single title slide explained orally to the class","A deck with dense paragraphs and a busy background theme"]', 'A 3–5 slide instructional deck with a consistent theme, readable fonts, one clear idea per slide, and at least one relevant image, icon, or chart on each content slide')
  ) AS q(pos, question, options, correct_answer);

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'ict1_final_rebuild_part1: inserted % ICT1 slide-based questions at positions 1–50 for FINAL EXAMINATION (%)', v_n, v_quiz;
END $$;
