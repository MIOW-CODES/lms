-- Course: ICT1 — Quiz 5 — Week 5 (Slide: WEEK 5 Online Collaboration Tools Gmail • Google Drive)
--
-- ICT1 Quiz 5 — 10 multiple-choice questions grounded strictly in the Week 5
-- lecture slides "Online Collaboration Tools" (Gmail / Google Drive).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If missing: NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 5' exists on ICT1: keep the quiz row, hard
--     delete its old quiz_questions rows, insert this slide-based set, and
--     refresh duration_minutes = 20 / question_count = 10. opens_at, closes_at,
--     score_released and answer_key_released are left untouched so a teacher's
--     availability/release state survives re-seeding.
--   * Otherwise: insert the quiz + its questions (duration 20, opens_at NULL,
--     closes_at now() + 14 days, score/answer key not released).
--   * Note on numbering: this migration supersedes earlier inline quiz seeds;
--     'Quiz 5' now covers the Week 5 slide content. Any existing 'Quiz 5'
--     question set (e.g. from 20261012000014) is replaced by this one.
--
-- Questions ordered roughly by slide order (positions 1..10); mix of recall +
-- application.
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
  SELECT v_course, 'Quiz 5', 20, 10, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 20, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz5_week5: Quiz 5 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz5_week5: created Quiz 5 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 5, why are email and cloud tools important for teachers?', '["Teachers rarely work alone — the tools let them communicate with parents, co-plan with colleagues, and share materials instantly","They replace the need for lesson planning","They are used only for making slide decks","They grade student work automatically"]', 'Teachers rarely work alone — the tools let them communicate with parents, co-plan with colleagues, and share materials instantly'),
    (2,  'What does Week 5 say a clear subject line should do?', '["State the purpose so the reader knows what to expect before opening","Show every detail of the message so the body is not needed","Be as short as possible, even a single word","List the names of everyone receiving the email"]', 'State the purpose so the reader knows what to expect before opening'),
    (3,  'What does a professional tone in school email mean?', '["Use a greeting, complete sentences, and a polite closing — even for quick notes","Write in all capital letters to show importance","Keep the message to a few words with no greeting","Use the same tone as a chat message with friends"]', 'Use a greeting, complete sentences, and a polite closing — even for quick notes'),
    (4,  'Before sending an email with a lesson plan attached, what does Week 5 tell you to check?', '["That the files are attached and named clearly","That the subject line is left empty","That the email was sent to the whole class","That the attachment was saved in Google Drive"]', 'That the files are attached and named clearly'),
    (5,  'How should a teacher organize lesson materials in Google Drive?', '["Create folders by subject or class to keep materials organized","Keep every file in one long unsorted list","Store files only on the classroom desktop","Give files random names so they are hard to guess"]', 'Create folders by subject or class to keep materials organized'),
    (6,  'Which three permission levels can you choose when sharing a Google Drive file?', '["Viewer, Commenter, or Editor","Reader, Writer, or Admin","Viewer, Editor, or Owner","Student, Teacher, or Parent"]', 'Viewer, Commenter, or Editor'),
    (7,  'A teacher wants colleagues to leave suggestions on a lesson plan without changing the text itself. Which permission should be chosen?', '["Commenter","Editor","Viewer","Owner"]', 'Commenter'),
    (8,  'Why does Week 5 warn about choosing the wrong Drive permission?', '["It can accidentally let others edit — or block them from viewing at all","It can delete the file from Google Drive","It can send the file to everyone in the school","It can turn the document into a PDF"]', 'It can accidentally let others edit — or block them from viewing at all'),
    (9,  'Which digital etiquette reminder means you should suggest changes or leave a comment instead of deleting a teammate''s work?', '["Comment, Don''t Overwrite","Reply Promptly","Credit Contributions","Proofread Before Sending"]', 'Comment, Don''t Overwrite'),
    (10, 'A group finished co-editing their shared document. What should they do before class ends to submit it?', '["Email the instructor the shared document link","Print the shared document and hand it in","Post the link on social media","Submit a screenshot of the document"]', 'Email the instructor the shared document link')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz5_week5: Quiz 5 (%) now has 10 slide-based questions', v_quiz;
END $$;
