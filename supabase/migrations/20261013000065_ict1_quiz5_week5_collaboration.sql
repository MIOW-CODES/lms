-- Course: ICT1 — Quiz 5 — Week 5 (Online Collaboration Tools)
--
-- ICT1 Quiz 5 — 20 multiple-choice questions grounded strictly in the Week 5
-- lecture slides "Online Collaboration Tools".
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 5' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz5_week5: course code ICT1 not found — skipping Quiz 5';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 5' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 5', 10, 20, NULL::timestamptz, now() + interval '14 days', false, false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 5' AND deleted_at IS NULL
  )
  RETURNING id INTO v_quiz;

  IF v_quiz IS NULL THEN
    -- Quiz already exists: replace its question set in place.
    SELECT id INTO v_quiz FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 5' AND deleted_at IS NULL
     ORDER BY created_at
     LIMIT 1;
    DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;
    UPDATE public.quizzes SET duration_minutes = 10, question_count = 20 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz5_week5: Quiz 5 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz5_week5: created Quiz 5 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What is the Week 5 learning outcome?', '["Use email and cloud tools for education","Navigate basic Learning Management System features","Create simple images and videos for teaching","Build a spreadsheet for recording student grades"]', 'Use email and cloud tools for education'),
    (2,  'Which learning resources are used in Week 5 for online collaboration?', '["Gmail and Google Drive","Google Classroom and Moodle","Canva and basic video editors","Microsoft Word and PowerPoint"]', 'Gmail and Google Drive'),
    (3,  'What assessment tool is used in Week 5, and how is it graded?', '["A checklist, graded on completion of each collaboration task during the group activity","A written examination, graded on memorized definitions of collaboration tools","A project rubric, graded on the image and video created during a workshop","A practical quiz, graded on hands-on navigation tasks inside the LMS"]', 'A checklist, graded on completion of each collaboration task during the group activity'),
    (4,  'According to Week 5, why are email and cloud tools important for teachers?', '["Teachers rarely work alone — the tools let them communicate with parents, co-plan with colleagues, and share materials instantly","They replace the need for lesson planning","They are used only for making slide decks","They grade student work automatically"]', 'Teachers rarely work alone — the tools let them communicate with parents, co-plan with colleagues, and share materials instantly'),
    (5,  'According to Week 5, what are shared docs for?', '["Co-edit plans and reports in real time","Storing lesson materials offline on a flash drive","Printing handouts for the whole class","Recording student attendance automatically"]', 'Co-edit plans and reports in real time'),
    (6,  'What does Week 5 say a clear subject line should do?', '["State the purpose so the reader knows what to expect before opening","Show every detail of the message so the body is not needed","Be as short as possible, even a single word","List the names of everyone receiving the email"]', 'State the purpose so the reader knows what to expect before opening'),
    (7,  'What does a professional tone in school email mean?', '["Use a greeting, complete sentences, and a polite closing — even for quick notes","Write in all capital letters to show importance","Keep the message to a few words with no greeting","Use the same tone as a chat message with friends"]', 'Use a greeting, complete sentences, and a polite closing — even for quick notes'),
    (8,  'Before sending an email with a lesson plan attached, what does Week 5 tell you to check?', '["That the files are attached and named clearly","That the subject line is left empty","That the email was sent to the whole class","That the attachment was saved in Google Drive"]', 'That the files are attached and named clearly'),
    (9,  'Why does Week 5 tell you to proofread before sending an email?', '["Because email represents you professionally","Because an email cannot be sent without a signature","Because proofreading adds attachments automatically","Because proofreading shortens the recipient''s inbox"]', 'Because email represents you professionally'),
    (10, 'How should a teacher organize lesson materials in Google Drive?', '["Create folders by subject or class to keep materials organized","Keep every file in one long unsorted list","Store files only on the classroom desktop","Give files random names so they are hard to guess"]', 'Create folders by subject or class to keep materials organized'),
    (11, 'After uploading a file to Google Drive, what does the Week 5 demonstration tell you to do next?', '["Rename it using a clear, consistent format","Delete it right away to save storage space","Convert it into a printed handout","Set it to private with sharing turned off completely"]', 'Rename it using a clear, consistent format'),
    (12, 'In the Google Drive sharing demonstration, how do you grant a colleague access to a file?', '["Click Share and add the colleague''s email","Send the file as an email attachment instead","Rename the file to include the colleague''s name","Move the file onto the colleague''s computer"]', 'Click Share and add the colleague''s email'),
    (13, 'Which three permission levels can you choose when sharing a Google Drive file?', '["Viewer, Commenter, or Editor","Reader, Writer, or Admin","Viewer, Editor, or Owner","Student, Teacher, or Parent"]', 'Viewer, Commenter, or Editor'),
    (14, 'A teacher wants colleagues to leave suggestions on a lesson plan without changing the text itself. Which permission should be chosen?', '["Commenter","Editor","Viewer","Owner"]', 'Commenter'),
    (15, 'Why does Week 5 warn about choosing the wrong Drive permission?', '["It can accidentally let others edit — or block them from viewing at all","It can delete the file from Google Drive","It can send the file to everyone in the school","It can turn the document into a PDF"]', 'It can accidentally let others edit — or block them from viewing at all'),
    (16, 'When does Week 5 say to generate a shareable link for a file in Google Drive?', '["For quick distribution to a class","To permanently delete the file","To convert the file into a PDF","To block everyone from viewing the file"]', 'For quick distribution to a class'),
    (17, 'According to the Week 5 group activity, how should the class work on the shared document?', '["Form small groups of 3–4 students and create one shared document with every group member added","Work alone and email separate documents to the instructor","Create one shared document but give access only to the group leader","Post the document publicly on social media"]', 'Form small groups of 3–4 students and create one shared document with every group member added'),
    (18, 'Which digital etiquette reminder means you should suggest changes or leave a comment instead of deleting a teammate''s work?', '["Comment, Don''t Overwrite","Reply Promptly","Credit Contributions","Proofread Before Sending"]', 'Comment, Don''t Overwrite'),
    (19, 'Which digital etiquette reminder says to acknowledge each member''s part when submitting shared work?', '["Credit Contributions","Comment, Don''t Overwrite","Reply Promptly","Proofread Before Sending"]', 'Credit Contributions'),
    (20, 'A group finished co-editing their shared document. According to the Week 5 checklist, what should they do before class ends to submit it?', '["Email the instructor the shared document link","Print the shared document and hand it in","Post the link on social media","Submit a screenshot of the document"]', 'Email the instructor the shared document link')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz5_week5: Quiz 5 (%) now has 20 slide-based questions', v_quiz;
END $$;
