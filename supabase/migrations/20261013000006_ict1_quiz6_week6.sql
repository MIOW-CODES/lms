-- Course: ICT1 — Quiz 6 — Week 6 (Slide: WEEK 6 Learning Management Systems (LMS) Google Classroom • Moodle)
--
-- ICT1 Quiz 6 — 10 multiple-choice questions grounded strictly in the Week 6
-- lecture slides "Learning Management Systems (LMS)" (Google Classroom / Moodle).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If missing: NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 6' exists on ICT1: keep the quiz row, hard
--     delete its old quiz_questions rows, insert this slide-based set, and
--     refresh duration_minutes = 20 / question_count = 10. opens_at, closes_at,
--     score_released and answer_key_released are left untouched so a teacher's
--     availability/release state survives re-seeding.
--   * Otherwise: insert the quiz + its questions (duration 20, opens_at NULL,
--     closes_at now() + 14 days, score/answer key not released).
--   * Note on numbering: this migration supersedes earlier inline quiz seeds;
--     'Quiz 6' now covers the Week 6 slide content. Any existing 'Quiz 6'
--     question set (e.g. from 20261012000015) is replaced by this one.
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
    RAISE NOTICE 'ict1_quiz6_week6: course code ICT1 not found — skipping Quiz 6';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 6' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 6', 20, 10, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 20, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz6_week6: Quiz 6 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz6_week6: created Quiz 6 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 6, what is a Learning Management System?', '["An online platform where teachers post materials, assignments, and grades — all in one place students can access anytime","A computer lab management program for schools","A video conferencing app for online classes","A spreadsheet used for recording grades only"]', 'An online platform where teachers post materials, assignments, and grades — all in one place students can access anytime'),
    (2,  'According to the Week 6 key takeaways, an LMS centralizes what in one place?', '["Materials, assignments, and grades","Students, teachers, and parents","Emails, chats, and video calls","Computers, printers, and projectors"]', 'Materials, assignments, and grades'),
    (3,  'Which LMS feature lets a teacher reach the whole class instantly?', '["Announcements","Gradebook","Attachments","Templates"]', 'Announcements'),
    (4,  'What is the Gradebook in an LMS?', '["A running record of scores that both teacher and student can view","A list of all files posted in the course","A calendar of school events","A tool for creating lesson slides"]', 'A running record of scores that both teacher and student can view'),
    (5,  'What are LMS notifications?', '["Automatic alerts when new content or due dates are posted","Pop-up advertisements inside the course","Reminders sent only to the teacher","A weekly email newsletter from the school"]', 'Automatic alerts when new content or due dates are posted'),
    (6,  'A teacher wants to see who has and who has not submitted a worksheet. Which core LMS feature should they use?', '["Assignments & Submissions","Course Stream / Materials","Notifications","Gradebook"]', 'Assignments & Submissions'),
    (7,  'A student uploaded a file to an assignment but forgot to click ''Turn in''. What does Week 6 warn will often show?', '["The assignment often shows as missing, even if the file was uploaded","The file is deleted from the LMS","The gradebook records a perfect score","The assignment is submitted automatically"]', 'The assignment often shows as missing, even if the file was uploaded'),
    (8,  'Where should students look to see the files, readings, and announcements posted for a class?', '["The course stream or materials tab","The gradebook","The notification settings","The school website"]', 'The course stream or materials tab'),
    (9,  'How does Week 6 compare Google Classroom and Moodle?', '["Google Classroom is simple and lightweight with Google integrations; Moodle is more customizable and feature-rich","Google Classroom is only for universities; Moodle is only for elementary school","They are two names for the same platform","Moodle integrates with Google Docs and Drive; Google Classroom does not"]', 'Google Classroom is simple and lightweight with Google integrations; Moodle is more customizable and feature-rich'),
    (10, 'In the Week 6 practical quiz, what does the ''Submit an Assignment'' task require?', '["Correctly turn in a sample assignment, not just upload a file","Simply upload a file without turning it in","Email the file to the teacher","Post the file in the course announcements"]', 'Correctly turn in a sample assignment, not just upload a file')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz6_week6: Quiz 6 (%) now has 10 slide-based questions', v_quiz;
END $$;
