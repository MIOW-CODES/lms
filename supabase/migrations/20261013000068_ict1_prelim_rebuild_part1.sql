-- Course: ICT1 — PRELIM EXAMINATION (Coverage: Weeks 1-7) — Part 1 (questions 1–50, Weeks 1–4)
--
-- ICT1 PRELIM EXAMINATION — Part 1: 50 multiple-choice questions grounded strictly
-- in ICT1's own course materials:
--   Positions 1–5   — Week 1 orientation (course ICT 1 – Information Communication 1,
--                     College 3rd Year, B8, Dr. Alan L. Vergara, course roadmap,
--                     assessment structure)
--   Positions 6–20  — Week 2: Productivity Tools in Education (MS Word • Google Docs)
--   Positions 21–35 — Week 3: Spreadsheet Applications (MS Excel • Google Sheets)
--   Positions 36–50 — Week 4: Presentation Tools (PowerPoint • Google Slides)
-- Knowledge exam only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1', never a hard-coded uuid. If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'PRELIM EXAMINATION (Coverage: Weeks 1-7)' exists
--     on ICT1: reuse the quiz row as-is — duration_minutes, question_count,
--     availability (opens_at/closes_at), score_released and answer_key_released
--     are NEVER touched here.
--   * Otherwise: INSERT the quiz row (duration_minutes = 60,
--     question_count = 80, opens_at NULL, closes_at = now() + 14 days,
--     score_released = false, answer_key_released = false).
--   * Question replacement is scoped to this part's range ONLY:
--     DELETE positions 1–50, then insert positions 1..50. Positions 51–100 are
--     owned by a second lane migration and are never touched here.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_prelim_rebuild_part1: course code ICT1 not found — skipping PRELIM EXAMINATION part 1';
    RETURN;
  END IF;
  RAISE NOTICE 'ict1_prelim_rebuild_part1: resolved course ICT1 (%)', v_course;

  -- Reuse an existing active PRELIM EXAMINATION quiz row untouched, else create one.
  SELECT id INTO v_quiz FROM public.quizzes
   WHERE course_id = v_course
     AND title = 'PRELIM EXAMINATION (Coverage: Weeks 1-7)'
     AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    INSERT INTO public.quizzes
      (course_id, title, duration_minutes, question_count, opens_at, closes_at,
       score_released, answer_key_released)
    VALUES
      (v_course, 'PRELIM EXAMINATION (Coverage: Weeks 1-7)', 60, 80, NULL::timestamptz,
       now() + interval '14 days', false, false)
    RETURNING id INTO v_quiz;
    RAISE NOTICE 'ict1_prelim_rebuild_part1: created PRELIM EXAMINATION quiz (%)', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_prelim_rebuild_part1: reusing PRELIM EXAMINATION quiz (%) — duration/question_count/availability/release left untouched', v_quiz;
  END IF;

  -- Replace ONLY positions 1–50 (owned by part 1); positions 51–100 untouched.
  DELETE FROM public.quiz_questions
   WHERE quiz_id = v_quiz AND position BETWEEN 1 AND 50;
  RAISE NOTICE 'ict1_prelim_rebuild_part1: cleared prior questions in positions 1–50';

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What is the full title of the course with code ICT1?', '["Introduction to Computing 1","Information Communication 1","Information and Communications Technology 1","Internet and Computer Technology 1"]', 'Information Communication 1'),
    (2,  'For which year level and section is ICT 1 handled under the course orientation?', '["College 2nd Year, B8","Senior High School Grade 12, B8","College 3rd Year, B8","College 3rd Year, A8"]', 'College 3rd Year, B8'),
    (3,  'Who is the instructor of ICT 1 – Information Communication 1?', '["Dr. Alan B. Garcia","Dr. Alan L. Vergara","Prof. Alberto L. Vergara","Mr. Alan L. Villanueva"]', 'Dr. Alan L. Vergara'),
    (4,  'Which sequence correctly lists the ICT 1 course roadmap from Week 2 to Week 7?', '["Week 2 Spreadsheets, Week 3 Productivity Tools, Week 4 Presentations, Week 5 LMS, Week 6 Online Collaboration, Week 7 Multimedia","Week 2 Productivity Tools, Week 3 Presentations, Week 4 Spreadsheets, Week 5 Multimedia, Week 6 LMS, Week 7 Online Collaboration","Week 2 Productivity Tools, Week 3 Spreadsheets, Week 4 Presentations, Week 5 Online Collaboration, Week 6 LMS, Week 7 Multimedia","Week 2 Multimedia, Week 3 LMS, Week 4 Online Collaboration, Week 5 Presentations, Week 6 Spreadsheets, Week 7 Productivity Tools"]', 'Week 2 Productivity Tools, Week 3 Spreadsheets, Week 4 Presentations, Week 5 Online Collaboration, Week 6 LMS, Week 7 Multimedia'),
    (5,  'Which assessment structure matches the course orientation for ICT 1?', '["5 quizzes (50 items, 30 minutes each), a PRELIM covering Weeks 1-4 (60 minutes), and a FINAL (50 items, 30 minutes)","3 quizzes (20 items, 10 minutes each), a PRELIM covering Weeks 5-7 (60 minutes), and a FINAL (100 items, 30 minutes)","7 quizzes (10 items, 5 minutes each), a MIDTERM covering Weeks 1-7 (90 minutes), and a FINAL (200 items, 120 minutes)","7 quizzes (20 items, 10 minutes each), a PRELIM covering Weeks 1-7 (60 minutes), and a FINAL (100 items, 60 minutes)"]', '7 quizzes (20 items, 10 minutes each), a PRELIM covering Weeks 1-7 (60 minutes), and a FINAL (100 items, 60 minutes)'),
    (6,  'According to Week 2, what is productivity software?', '["Software used only by programmers to write and debug computer code","A grading system that automatically computes student rankings","Applications designed to help you create, organize, and manage everyday teaching tasks — faster and more consistently than by hand","Computer hardware that speeds up document printing in the classroom"]', 'Applications designed to help you create, organize, and manage everyday teaching tasks — faster and more consistently than by hand'),
    (7,  'What is the Week 2 learning outcome for Productivity Tools in Education?', '["Create simple grade sheets and charts","Design instructional presentations that support teaching","Use word processing software effectively for lesson plans","Produce simple images and videos for teaching"]', 'Use word processing software effectively for lesson plans'),
    (8,  'Which learning resources are used in Week 2 for Productivity Tools in Education?', '["MS Excel and Google Sheets","PowerPoint and Google Slides","Google Classroom and Moodle","MS Word and Google Docs"]', 'MS Word and Google Docs'),
    (9,  'In the productivity software overview, which tool category is matched with lesson plans, letters, and worksheets?', '["Spreadsheets","Word processors","Presentation tools","Web browsers"]', 'Word processors'),
    (10, 'In the productivity software overview, which tool category is matched with grade sheets, records, and charts?', '["Word processors","Spreadsheets","Presentation tools","Email clients"]', 'Spreadsheets'),
    (11, 'In the productivity software overview, which tool category is matched with slide decks for instruction?', '["Presentation tools","Word processors","Spreadsheets","File compression utilities"]', 'Presentation tools'),
    (12, 'Why are reusable lesson plan templates valuable in Week 2?', '["They replace the need for learning objectives","They automatically submit the lesson plan to the LMS","They save prep time every week","They grade student output during the lesson"]', 'They save prep time every week'),
    (13, 'What is the benefit of cloud storage highlighted in Week 2?', '["Cloud storage prints lesson plans automatically before class","Google Docs autosaves and syncs across devices, so work is never lost","Files stored in the cloud cannot be shared with colleagues","Cloud storage removes the need for formatting and layout"]', 'Google Docs autosaves and syncs across devices, so work is never lost'),
    (14, 'In Week 2, what does sharing and collaboration allow teachers to do?', '["Lock the document so no one else can view it","Convert lesson plans into grade sheets automatically","Co-plan with colleagues and receive feedback through comments","Present the lesson plan as a slide deck"]', 'Co-plan with colleagues and receive feedback through comments'),
    (15, 'Which is the correct order of sections in the lesson plan document demonstrated in Week 2?', '["Assessment: how student learning will be checked → Procedure: introduction, activities, and closure → Materials and resources → Learning objectives → Header: subject, grade level, date, and duration","Header: subject, grade level, date, and duration → Learning objectives → Materials and resources → Procedure: introduction, activities, and closure → Assessment: how student learning will be checked","Learning objectives → Header: subject, grade level, date, and duration → Assessment: how student learning will be checked → Procedure: introduction, activities, and closure → Materials and resources","Materials and resources → Assessment: how student learning will be checked → Header: subject, grade level, date, and duration → Learning objectives → Procedure: introduction, activities, and closure"]', 'Header: subject, grade level, date, and duration → Learning objectives → Materials and resources → Procedure: introduction, activities, and closure → Assessment: how student learning will be checked'),
    (16, 'In a lesson plan document, learning objectives must be', '["Written only after the lesson is finished","Left blank so the teacher can improvise","Stated clearly and measurably","Listed only in the assessment section"]', 'Stated clearly and measurably'),
    (17, 'What does the procedure section of a lesson plan document contain?', '["The final grades and rankings of the students","Introduction, activities, and closure","Only the list of learning resources","Header, learning objectives, and materials"]', 'Introduction, activities, and closure'),
    (18, 'What does the assessment section of a lesson plan document describe?', '["How the teacher will format the document","Where the file will be stored in the cloud","Which fonts and colors the document uses","How student learning will be checked"]', 'How student learning will be checked'),
    (19, 'Why does the Week 2 demonstration use Styles (Heading 1/2) instead of manually bolding and resizing text?', '["It keeps the document consistent and makes a table of contents possible later","It makes the file size smaller for LMS submission","It converts the lesson plan into a spreadsheet","It allows the document to be printed in color only"]', 'It keeps the document consistent and makes a table of contents possible later'),
    (20, 'When reviewing a colleague''s lesson plan, what does Week 2 recommend?', '["Rewrite the document from scratch without telling them","Add comments rather than changing their text directly","Delete the sections you disagree with","Convert their lesson plan into a slide deck first"]', 'Add comments rather than changing their text directly'),
    (21, 'What is the Week 3 learning outcome for Spreadsheet Applications?', '["Use word processing software effectively for lesson plans","Create simple grade sheets and charts","Design instructional presentations that support teaching","Navigate basic LMS features"]', 'Create simple grade sheets and charts'),
    (22, 'Which learning resources are used in Week 3 for Spreadsheet Applications?', '["MS Word and Google Docs","MS Excel and Google Sheets","PowerPoint and Google Slides","Gmail and Google Drive"]', 'MS Excel and Google Sheets'),
    (23, 'According to Week 3, how does a spreadsheet organize information?', '["Into a slide deck so it can be presented to a class","Into paragraphs so it can be read like a letter","Into folders so it can be stored in the cloud","Into a grid so it can be calculated, sorted, and visualized quickly"]', 'Into a grid so it can be calculated, sorted, and visualized quickly'),
    (24, 'What is a cell in a spreadsheet?', '["A full grid of cells within a workbook","A single box where data or a formula lives","A line of labels that runs across the grid","A vertical strip of boxes that runs down the grid"]', 'A single box where data or a formula lives'),
    (25, 'How do rows and columns run in a spreadsheet grid?', '["Rows run down; columns run across","Both rows and columns run across","Rows run across; columns run down","Rows run diagonally; columns run vertically"]', 'Rows run across; columns run down'),
    (26, 'What is a sheet in a spreadsheet application?', '["A single box where data or a formula lives","A chart that visualizes student scores","A full grid of cells within a workbook","A printed page of the grade sheet"]', 'A full grid of cells within a workbook'),
    (27, 'In Week 3, what does SUM do for grading?', '["Calculates a student''s overall grade from multiple scores","Adds up scores across an assignment or a whole quarter","Arranges students by name, score, or ranking instantly","Shows only the rows you need"]', 'Adds up scores across an assignment or a whole quarter'),
    (28, 'In Week 3, what does AVERAGE do for grading?', '["Adds up scores across an assignment or a whole quarter","Calculates a student''s overall grade from multiple scores","Freezes the top row for easy scrolling","Inserts a bar or column chart of the class''s scores"]', 'Calculates a student''s overall grade from multiple scores'),
    (29, 'In Week 3, what does SORT do?', '["Shows only the rows you need","Adds up scores across an assignment or a whole quarter","Arranges students by name, score, or ranking instantly","Copies a formula down a column automatically"]', 'Arranges students by name, score, or ranking instantly'),
    (30, 'In Week 3, what does FILTER do?', '["Arranges students by name, score, or ranking instantly","Calculates a student''s overall grade from multiple scores","Formats the column headers in bold","Shows only the rows you need — for example, students below passing"]', 'Shows only the rows you need — for example, students below passing'),
    (31, 'What happens when you drag the fill handle in a grade sheet?', '["It deletes the raw scores of every student in the row","It copies a formula down the column automatically, avoiding retyping for every student","It converts the grade sheet into a slide presentation","It freezes the top row so headers stay visible"]', 'It copies a formula down the column automatically, avoiding retyping for every student'),
    (32, 'What does the Week 3 performance task require of the Total and Average columns?', '["They must be typed manually without any formulas","They must be added only after the chart is created","They must use formulas (=SUM and =AVERAGE), not manual math","They must be replaced by a written description of the scores"]', 'They must use formulas (=SUM and =AVERAGE), not manual math'),
    (33, 'Which chart is best for comparing scores across students or assignments?', '["Line Chart","Bar / Column Chart","Pie Chart","Area Chart"]', 'Bar / Column Chart'),
    (34, 'Which chart is best for tracking a student''s progress across the term?', '["Bar / Column Chart","Pie Chart","Line Chart","Radar Chart"]', 'Line Chart'),
    (35, 'Which chart is best for showing proportions, like a grade distribution?', '["Pie Chart","Line Chart","Bar / Column Chart","Scatter Chart"]', 'Pie Chart'),
    (36, 'What is the Week 4 learning outcome for Presentation Tools?', '["Create simple grade sheets and charts","Use word processing software effectively for lesson plans","Design instructional presentations that support teaching","Produce simple images and videos for teaching"]', 'Design instructional presentations that support teaching'),
    (37, 'Which learning resources are used in Week 4 for Presentation Tools?', '["MS Word and Google Docs","MS Excel and Google Sheets","Google Classroom and Moodle","PowerPoint and Google Slides"]', 'PowerPoint and Google Slides'),
    (38, 'What is the effect of a cluttered slide, according to Week 4?', '["Students read instead of listen","Students listen while the slide reinforces the point","Students absorb ideas faster than with a clear slide","Students focus only on the teacher''s voice"]', 'Students read instead of listen'),
    (39, 'Which slide is a clear slide, according to Week 4?', '["Dense paragraphs, tiny text, five colors, and a busy background","A full script of the lecture written out for students to read","One idea, a short phrase, and a supporting image — students listen while the slide reinforces the point","Several ideas at once with detailed explanations on each slide"]', 'One idea, a short phrase, and a supporting image — students listen while the slide reinforces the point'),
    (40, 'According to Week 4, how should slides be treated in teaching?', '["As visual support for your teaching, not a script to read aloud","As a script to read aloud so no content is missed","As a complete substitute for the teacher''s explanation","As a handout that students should copy word for word"]', 'As visual support for your teaching, not a script to read aloud'),
    (41, 'What does the principle One Idea Per Slide mean?', '["Each slide should contain exactly one image and no text","Each slide should present the entire lesson in one view","Each slide should make a single clear point, not several at once","Each slide should use exactly one color and one font"]', 'Each slide should make a single clear point, not several at once'),
    (42, 'What does the principle Consistent Color & Font require?', '["Use five colors and several fonts to keep slides lively","Change the theme on every slide to show variety","Use only black text on a white background for every slide","Pick one palette and one or two fonts, and use them throughout"]', 'Pick one palette and one or two fonts, and use them throughout'),
    (43, 'What does the principle Use Visuals, Not Walls of Text mean?', '["Full paragraphs should replace images on every slide","Images, icons, and diagrams communicate faster than paragraphs","Visuals should be used only as decoration","Text should be written in full sentences on every slide"]', 'Images, icons, and diagrams communicate faster than paragraphs'),
    (44, 'What does the principle Visual Hierarchy mean?', '["All text on a slide should be the same size","Titles should always be smaller than body text","Only the title of the deck should be formatted","Titles, subpoints, and body text should be sized to show what matters most"]', 'Titles, subpoints, and body text should be sized to show what matters most'),
    (45, 'According to Week 4''s rubric-based output, what must each content slide include?', '["At least one full paragraph explaining the topic","At least three colors and two different fonts","The complete script of the presentation","At least one relevant image, icon, or chart"]', 'At least one relevant image, icon, or chart'),
    (46, 'How should text be written on an instructional slide, per the Week 4 demonstration?', '["Write full sentences so students can read along silently","Copy the entire lesson script onto the slide","Trim text to keywords or short phrases, not full sentences","Use as many words as possible to cover every detail"]', 'Trim text to keywords or short phrases, not full sentences'),
    (47, 'Why does the Week 4 demonstration use the Slide Master?', '["To add animations to every slide automatically","To convert the slide deck into a word processing document","To print the deck in color for every student","To update fonts and colors across the whole deck at once, keeping every slide consistent without editing each one by hand"]', 'To update fonts and colors across the whole deck at once, keeping every slide consistent without editing each one by hand'),
    (48, 'What does the delivery tip Face the Class, Not the Screen mean?', '["Use the slide as a prompt for you — don''t turn your back to read it","Stand behind the screen while presenting the deck","Read every slide aloud word for word to the class","Face the laptop so the class cannot see the slides"]', 'Use the slide as a prompt for you — don''t turn your back to read it'),
    (49, 'What does the delivery tip Pause on Visuals mean?', '["Skip every chart or image so the presentation stays short","Give students a moment to look at a chart or image before you speak over it","Speak over visuals immediately so no time is wasted","Remove all visuals from the deck before presenting"]', 'Give students a moment to look at a chart or image before you speak over it'),
    (50, 'What is the graded deliverable for Week 4''s rubric-based output?', '["A one-page lesson plan in Word or Google Docs","A grade sheet with Total and Average columns and a chart","A 3–5 slide instructional deck on a topic of your choice, built in class","A 10-slide slide deck of full paragraphs built at home"]', 'A 3–5 slide instructional deck on a topic of your choice, built in class')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_prelim_rebuild_part1: inserted 50 ICT1 slide-based questions at positions 1–50 for PRELIM EXAMINATION (%)', v_quiz;
END $$;
