-- Course: ICT1 — Quiz 6 — Week 6 (Learning Management Systems)
--
-- ICT1 Quiz 6 — 20 multiple-choice questions grounded strictly in the Week 6
-- lecture slides "Learning Management Systems (LMS)".
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 6' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz6_week6: course code ICT1 not found — skipping Quiz 6';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 6' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 6', 10, 20, NULL::timestamptz, now() + interval '14 days', false, false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 6' AND deleted_at IS NULL
  )
  RETURNING id INTO v_quiz;

  IF v_quiz IS NULL THEN
    -- Quiz already exists: replace its question set in place.
    SELECT id INTO v_quiz FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 6' AND deleted_at IS NULL
     ORDER BY created_at
     LIMIT 1;
    DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;
    UPDATE public.quizzes SET duration_minutes = 10, question_count = 20 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz6_week6: Quiz 6 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz6_week6: created Quiz 6 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What is the Week 6 learning outcome?', '["Navigate basic LMS features","Use email and cloud tools for education","Create simple images and videos for teaching","Design a school website from scratch"]', 'Navigate basic LMS features'),
    (2,  'Which learning resources are used in Week 6 to explore LMS features?', '["Google Classroom and Moodle","Gmail and Google Drive","Canva and basic video editors","Microsoft Teams and Zoom"]', 'Google Classroom and Moodle'),
    (3,  'What assessment tool is used in Week 6, and how is it graded?', '["A practical quiz, graded on hands-on navigation tasks completed inside the LMS","A checklist, graded on completion of each collaboration task","A project rubric, graded on the image and video created during a workshop","A written examination, graded on memorized LMS definitions"]', 'A practical quiz, graded on hands-on navigation tasks completed inside the LMS'),
    (4,  'According to Week 6, what is a Learning Management System?', '["An online platform where teachers post materials, assignments, and grades — all in one place students can access anytime","A computer lab management program for schools","A video conferencing app for online classes","A spreadsheet used for recording grades only"]', 'An online platform where teachers post materials, assignments, and grades — all in one place students can access anytime'),
    (5,  'According to the Week 6 key takeaways, an LMS centralizes what in one place?', '["Materials, assignments, and grades","Students, teachers, and parents","Emails, chats, and video calls","Computers, printers, and projectors"]', 'Materials, assignments, and grades'),
    (6,  'What does Week 6 say the course materials area of an LMS contains?', '["Readings, slides, and files in one place","Only the teacher''s grade records","The school''s enrollment forms","A calendar of extracurricular events"]', 'Readings, slides, and files in one place'),
    (7,  'How do students submit their work in an LMS?', '["They submit work directly online","They print it and hand it to the teacher","They email it to the whole class","They post it on social media"]', 'They submit work directly online'),
    (8,  'Which LMS feature lets a teacher reach the whole class instantly?', '["Announcements","Gradebook","Attachments","Templates"]', 'Announcements'),
    (9,  'What is the Gradebook in an LMS?', '["A running record of scores that both teacher and student can view","A list of all files posted in the course","A calendar of school events","A tool for creating lesson slides"]', 'A running record of scores that both teacher and student can view'),
    (10, 'What are LMS notifications?', '["Automatic alerts when new content or due dates are posted","Pop-up advertisements inside the course","Reminders sent only to the teacher","A weekly email newsletter from the school"]', 'Automatic alerts when new content or due dates are posted'),
    (11, 'A teacher wants to see who has and who has not submitted a worksheet. Which core LMS feature should they use?', '["Assignments & Submissions","Course Stream / Materials","Notifications","Gradebook"]', 'Assignments & Submissions'),
    (12, 'Where should students look to see the files, readings, and announcements posted for a class?', '["The course stream or materials tab","The gradebook","The notification settings","The school website"]', 'The course stream or materials tab'),
    (13, 'According to the Week 6 LMS demonstration, what is the first step in navigating the LMS?', '["Log in and locate your enrolled class or course","Open the gradebook and edit a score","Post an announcement to the whole class","Upload a file to the school website"]', 'Log in and locate your enrolled class or course'),
    (14, 'According to the Week 6 demonstration, what should you do right after opening an assignment?', '["Review its instructions and due date","Delete the assignment to free up space","Turn it in without reading anything","Email the teacher to cancel the assignment"]', 'Review its instructions and due date'),
    (15, 'What can you submit through the LMS assignment page?', '["A file or a text response","Only a printed hard copy","Only a video recorded in class","Nothing — assignments cannot be submitted online"]', 'A file or a text response'),
    (16, 'A student uploaded a file to an assignment but forgot to click ''Turn in''. What does Week 6 warn will often show?', '["The assignment often shows as missing, even if the file was uploaded","The file is deleted from the LMS","The gradebook records a perfect score","The assignment is submitted automatically"]', 'The assignment often shows as missing, even if the file was uploaded'),
    (17, 'What does Week 6 say is a key advantage of Google Classroom?', '["It is simple and lightweight and integrates directly with Google Docs, Drive, and Gmail","It is the most customizable platform available","It is used only by universities and larger institutions","It works without an internet connection"]', 'It is simple and lightweight and integrates directly with Google Docs, Drive, and Gmail'),
    (18, 'What does Week 6 say about Moodle?', '["It is more customizable and feature-rich, and is common in universities and larger institutions","It is simple and lightweight with Google integrations","It works only on mobile phones","It is a spreadsheet tool for recording grades"]', 'It is more customizable and feature-rich, and is common in universities and larger institutions'),
    (19, 'In the Week 6 practical quiz, what does the ''Submit an Assignment'' task require?', '["Correctly turn in a sample assignment, not just upload a file","Simply upload a file without turning it in","Email the file to the teacher","Post the file in the course announcements"]', 'Correctly turn in a sample assignment, not just upload a file'),
    (20, 'In the Week 6 practical quiz, what does the ''Check the Gradebook'' task require?', '["Locate feedback or a score for a previously submitted item","Change a grade in the gradebook","Delete an old submission","Create a new assignment for the class"]', 'Locate feedback or a score for a previously submitted item')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz6_week6: Quiz 6 (%) now has 20 slide-based questions', v_quiz;
END $$;
