-- Course: ICT1 — Quiz 2 — Week 2 (Productivity Tools in Education: MS Word and Google Docs)
--
-- ICT1 Quiz 2 — 20 multiple-choice questions grounded strictly in the Week 2
-- lecture deck "Productivity Tools in Education (MS Word • Google Docs)".
-- Knowledge + application quiz only: no lab_task items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 2' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz2_week2_productivity: course code ICT1 not found — skipping Quiz 2';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 2' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 2', 10, 20, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 10, question_count = 20 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz2_week2_productivity: Quiz 2 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz2_week2_productivity: created Quiz 2 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to the Week 2 learning outcome, what should students be able to do by the end of the session?', '["Use word processing software effectively for lesson plans","Build interactive spreadsheets with formulas and charts","Design multimedia presentations for classroom instruction","Administer a learning management system for online classes"]', 'Use word processing software effectively for lesson plans'),
    (2,  'Which applications are the listed learning resources for Week 2?', '["MS Word and Google Docs","MS Excel and Google Sheets","PowerPoint and Google Slides","Moodle and Google Classroom"]', 'MS Word and Google Docs'),
    (3,  'What is the assessment tool for Week 2?', '["An Output-Based Activity graded on the completed lesson plan document produced in class","A written seatwork on productivity software definitions","A multiple-choice quiz on word processing history","A group presentation about cloud storage services"]', 'An Output-Based Activity graded on the completed lesson plan document produced in class'),
    (4,  'In the Week 2 agenda, which activity comes immediately after the Word Processing Demo?', '["Guided Practice","What Is Productivity Software?","Output-Based Activity","Questions and Closing Remarks"]', 'Guided Practice'),
    (5,  'According to Week 2, what is productivity software?', '["Applications designed to help you create, organize, and manage everyday teaching tasks — faster and more consistently than by hand","Software used only by accountants and business offices for payroll","Hardware tools that speed up the processors of classroom computers","Online games designed to make student lessons more entertaining"]', 'Applications designed to help you create, organize, and manage everyday teaching tasks — faster and more consistently than by hand'),
    (6,  'Which tasks do word processors handle in the classroom?', '["Lesson plans, letters, and worksheets","Grade sheets, records, and charts","Slide decks for instruction","Video clips and audio recordings"]', 'Lesson plans, letters, and worksheets'),
    (7,  'A teacher needs to produce grade sheets, records, and charts for a class. Which productivity tool category fits the task?', '["Spreadsheets","Word processors","Presentation tools","Multimedia authoring tools"]', 'Spreadsheets'),
    (8,  'In the classroom, what keeps lesson plans readable and consistent?', '["Formatting & Layout — headings, spacing, and tables","Cloud Storage — autosaving files across devices","Templates — reusable lesson plan shells","Sharing & Collaboration — comments from colleagues"]', 'Formatting & Layout — headings, spacing, and tables'),
    (9,  'What is the benefit of cloud storage highlighted in Week 2?', '["Google Docs autosaves and syncs across devices, so work is never lost","Cloud storage makes printed handouts look more colorful","Cloud storage replaces the need to state learning objectives","Files stored in the cloud cannot be shared with colleagues"]', 'Google Docs autosaves and syncs across devices, so work is never lost'),
    (10, 'A teacher wants to co-plan a lesson with a colleague and receive feedback on the draft. Which word processing benefit applies?', '["Sharing & Collaboration — co-plan with colleagues and receive feedback through comments","Formatting & Layout — adjust headings, spacing, and tables","Templates — reuse a lesson plan template every week","Cloud Storage — autosave the document across devices"]', 'Sharing & Collaboration — co-plan with colleagues and receive feedback through comments'),
    (11, 'What belongs in the header of a lesson plan document?', '["Subject, grade level, date, and duration","Introduction, activities, and closure","Materials and resources needed for the lesson","How student learning will be checked"]', 'Subject, grade level, date, and duration'),
    (12, 'What does the Procedure section of a lesson plan contain?', '["Introduction, activities, and closure","Subject, grade level, date, and duration","Learning objectives stated clearly and measurably","The grading rubric and the honor pledge"]', 'Introduction, activities, and closure'),
    (13, 'Which of the following is NOT one of the five parts of the lesson plan document demonstrated in Week 2?', '["A bibliography and APA reference list","The header with subject, grade level, date, and duration","Learning objectives stated clearly and measurably","Assessment: how student learning will be checked"]', 'A bibliography and APA reference list'),
    (14, 'Why should the instructor use Styles (Heading 1/2) instead of manually bolding and resizing text?', '["It keeps the document consistent and makes a table of contents possible later","It makes the printed lesson plan use less ink","It automatically adds a bibliography and APA reference list","It converts the lesson plan into a slide deck for instruction"]', 'It keeps the document consistent and makes a table of contents possible later'),
    (15, 'During guided practice, what should students apply to their section titles?', '["Heading styles","Manual bold and manual font resizing","Double column newspaper layout","Watermarks and page borders"]', 'Heading styles'),
    (16, 'How should students save or rename their lesson plan file during guided practice?', '["Using the class naming format","Any name, since the file is never graded","With the default name Document1 or Untitled document","With the date only, in any format they prefer"]', 'Using the class naming format'),
    (17, 'When reviewing the lesson plan of a colleague, what does Week 2 recommend?', '["Use comments, not edits — add comments rather than changing their text directly","Edit the text directly so the document is corrected immediately","Print the plan and rewrite it by hand","Start a new blank document instead"]', 'Use comments, not edits — add comments rather than changing their text directly'),
    (18, 'What is the recommended practice for building lesson plan templates?', '["Build a template once and reuse it all term — do not start from a blank page each time","Start from a blank page each week to keep the lesson plans original","Type every lesson plan directly on the LMS announcement box","Copy a lesson plan from a colleague and change only the date"]', 'Build a template once and reuse it all term — do not start from a blank page each time'),
    (19, 'What is the deliverable for the Week 2 Output-Based Activity?', '["A complete one-page lesson plan created during class, in Word or Google Docs","A slide deck presenting the steps of word processing","A spreadsheet of student grades for the term","A reflection essay about productivity software"]', 'A complete one-page lesson plan created during class, in Word or Google Docs'),
    (20, 'Which sections must the submitted lesson plan include?', '["Header, objectives, materials, procedure, and assessment","Title page, abstract, methodology, and bibliography","Introduction, literature review, results, and discussion","Cover letter, resume, and portfolio of outputs"]', 'Header, objectives, materials, procedure, and assessment')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz2_week2_productivity: Quiz 2 (%) now has 20 slide-based questions', v_quiz;
END $$;
