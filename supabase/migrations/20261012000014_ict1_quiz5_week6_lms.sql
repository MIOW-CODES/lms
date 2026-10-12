-- Course: ICT1 (ICT 1 - LAB) — Quiz 5 — Week 6 (Slide: WEEK 6 Learning Management Systems (LMS))
--
-- Slide-grounded knowledge quiz (10 multiple-choice items, 4 options each) authored
-- strictly from the Week 6 lecture slide text (docs/ICT1/ICT1_Week6 Learning
-- Management Systems.pptx): what an LMS is, the three things it centralizes,
-- announcements, core features (stream/materials, assignments & submissions,
-- notifications, gradebook), the navigation flow and the Turn-in trap, and
-- Google Classroom vs. Moodle. Mix of recall + application, ordered by slide
-- order (position 1..10).
--
-- Note on numbering: quiz numbering follows the course series — Quiz 4 / Week 5
-- is intentionally skipped; Quiz 5 covers Week 6 content.
--
-- UPSERT semantics (fully idempotent, safe to re-run):
--   * Course is resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If the course is missing, the block raises a NOTICE and does nothing.
--   * If an active quiz titled exactly 'Quiz 5' already exists on the ICT1 course,
--     its quiz_questions rows are replaced (old rows deleted, the new slide-based
--     set inserted) and the quiz row's duration_minutes/question_count are
--     refreshed to the seeded values so the row stays consistent with the new
--     10-question set. opens_at, closes_at, score_released and answer_key_released
--     are left untouched on an existing row so a teacher's availability/release
--     state survives re-seeding.
--   * Otherwise the quiz row + questions are inserted fresh: opens_at NULL
--     (open now — see 20261006000002), closes_at = now() + 14 days (same window as
--     the other inline quiz seeds), score_released/answer_key_released false until
--     the teacher releases.
--   * Re-running replaces the same 10 rows — never duplicates.
--
-- 10 questions, duration_minutes = 15, lab_task = false, required = false,
-- no images and NO attachments (the new pptx files are not in Supabase storage).

DO $ict1_quiz5_week6_lms$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  -- ── Course lookup: ICT1 by its unique code, never a hard-coded uuid ───────
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_quiz5_week6_lms: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  -- ── UPSERT: reuse an active 'Quiz 5' on ICT1, otherwise insert one ────────
  SELECT id INTO v_quiz
    FROM public.quizzes
   WHERE course_id = v_course AND title = 'Quiz 5' AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    INSERT INTO public.quizzes
      (course_id, title, duration_minutes, question_count, opens_at, closes_at,
       score_released, answer_key_released)
    SELECT v_course, 'Quiz 5', 15, 10, NULL, now() + interval '14 days', false, false
    WHERE NOT EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE course_id = v_course AND title = 'Quiz 5' AND deleted_at IS NULL
    )
    RETURNING id INTO v_quiz;

    IF v_quiz IS NULL THEN
      RAISE NOTICE 'ict1_quiz5_week6_lms: a Quiz 5 row appeared meanwhile - questions left untouched';
      RETURN;
    END IF;
    RAISE NOTICE 'ict1_quiz5_week6_lms: created quiz % (Week 6 LMS, 10 questions)', v_quiz;
  ELSE
    -- Refresh only the seeded presentation config; availability/release state stays.
    UPDATE public.quizzes
       SET duration_minutes = 15,
           question_count = 10
     WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz5_week6_lms: quiz % exists - replacing its questions', v_quiz;
  END IF;

  -- ── Replace the question set (idempotent) ────────────────────────────────
  DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What is a Learning Management System (LMS)?', '["An online platform where teachers post materials, assignments, and grades in one place","A printer for producing classroom handouts","A charging station for student laptops","A social media app for chatting with friends"]', 'An online platform where teachers post materials, assignments, and grades in one place'),
    (2,  'An LMS keeps which of these in one place that students can access anytime?', '["Materials, assignments, and grades","Only student attendance records","Only teacher lesson plans","School cafeteria menus"]', 'Materials, assignments, and grades'),
    (3,  'What is the purpose of announcements in an LMS?', '["Reach the whole class instantly","Replace the gradebook entirely","Store backup copies of every file","Track who has and has not submitted work"]', 'Reach the whole class instantly'),
    (4,  'Which LMS feature is a running record of scores that both teacher and student can view?', '["Gradebook","Notifications","Course stream","Assignment page"]', 'Gradebook'),
    (5,  'Which LMS feature sends automatic alerts when new content or due dates are posted?', '["Notifications","Gradebook","Submissions","The login screen"]', 'Notifications'),
    (6,  'A teacher wants to find out which students have and have not turned in their work. Which LMS feature shows this?', '["Assignments and Submissions","Notifications","Announcements","The course stream"]', 'Assignments and Submissions'),
    (7,  'A student uploads a file to an assignment but never presses Turn in. How will the assignment often appear?', '["Missing, even though the file was uploaded","Graded and fully submitted","Archived with full marks","Nothing — an upload counts as a submission"]', 'Missing, even though the file was uploaded'),
    (8,  'You need to check what an assignment requires and when it is due. What should you do in the LMS?', '["Open the assignment and review its instructions and due date","Look only at the gradebook","Wait until the due date has passed","Ask a classmate because the LMS hides due dates"]', 'Open the assignment and review its instructions and due date'),
    (9,  'Google Classroom integrates directly with which tools?', '["Google Docs, Drive, and Gmail","Microsoft Word, Excel, and PowerPoint","Canva and basic video editors","Moodle and university servers"]', 'Google Docs, Drive, and Gmail'),
    (10, 'Which LMS platform is more customizable and feature-rich, and is common in universities and larger institutions?', '["Moodle","Google Classroom","Google Docs","Gmail"]', 'Moodle')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz5_week6_lms: seeded 10 questions on quiz %', v_quiz;
END $ict1_quiz5_week6_lms$;
