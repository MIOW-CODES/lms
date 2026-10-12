-- Course: ICT1 (ICT 1 - LAB) — Quiz 6 — Week 7 (Slide: WEEK 7 Multimedia in Education)
--
-- Slide-grounded knowledge quiz (10 multiple-choice items, 4 options each) authored
-- strictly from the Week 7 lecture slide text (docs/ICT1/ICT1_Week7 Multimedia in
-- Education.pptx): why multimedia matters (images vs. short videos), designing
-- instructional graphics in Canva (templates, stock photos & icons, resize & crop,
-- export & share), the basic video-editing flow (import, trim, caption/title,
-- transition, export) and its watch-outs, and tips for effective multimedia.
-- Mix of recall + application, ordered by slide order (position 1..10).
--
-- Note on numbering: quiz numbering follows the course series — Quiz 4 / Week 5
-- is intentionally skipped; Quiz 6 covers Week 7 content.
--
-- UPSERT semantics (fully idempotent, safe to re-run):
--   * Course is resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If the course is missing, the block raises a NOTICE and does nothing.
--   * If an active quiz titled exactly 'Quiz 6' already exists on the ICT1 course,
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

DO $ict1_quiz6_week7_multimedia$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  -- ── Course lookup: ICT1 by its unique code, never a hard-coded uuid ───────
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_quiz6_week7_multimedia: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  -- ── UPSERT: reuse an active 'Quiz 6' on ICT1, otherwise insert one ────────
  SELECT id INTO v_quiz
    FROM public.quizzes
   WHERE course_id = v_course AND title = 'Quiz 6' AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    INSERT INTO public.quizzes
      (course_id, title, duration_minutes, question_count, opens_at, closes_at,
       score_released, answer_key_released)
    SELECT v_course, 'Quiz 6', 15, 10, NULL, now() + interval '14 days', false, false
    WHERE NOT EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE course_id = v_course AND title = 'Quiz 6' AND deleted_at IS NULL
    )
    RETURNING id INTO v_quiz;

    IF v_quiz IS NULL THEN
      RAISE NOTICE 'ict1_quiz6_week7_multimedia: a Quiz 6 row appeared meanwhile - questions left untouched';
      RETURN;
    END IF;
    RAISE NOTICE 'ict1_quiz6_week7_multimedia: created quiz % (Week 7 Multimedia, 10 questions)', v_quiz;
  ELSE
    -- Refresh only the seeded presentation config; availability/release state stays.
    UPDATE public.quizzes
       SET duration_minutes = 15,
           question_count = 10
     WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz6_week7_multimedia: quiz % exists - replacing its questions', v_quiz;
  END IF;

  -- ── Replace the question set (idempotent) ────────────────────────────────
  DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'Why are images and short videos used in teaching?', '["They help students grasp ideas that are hard to explain in words alone","They make lesson plans unnecessary","They replace all written examinations","They work only for art subjects"]', 'They help students grasp ideas that are hard to explain in words alone'),
    (2,  'What do short videos show especially well?', '["A process or demonstration in motion","A concept in one glance","A student grade record","The class announcements"]', 'A process or demonstration in motion'),
    (3,  'A teacher has no design experience but needs a simple visual for class. Which tool does the lesson suggest?', '["Canva","Moodle","Google Classroom","A video encoder"]', 'Canva'),
    (4,  'In Canva, what should you use instead of starting from a blank page?', '["A ready-made template","A scanned photograph","A Moodle course export","A video transition"]', 'A ready-made template'),
    (5,  'Which Canva feature adjusts dimensions for posters, slides, or social posts with one click?', '["Resize and Crop","Stock Photos and Icons","Export and Share","Templates"]', 'Resize and Crop'),
    (6,  'How can you get a finished Canva design to your students?', '["Download it as an image or PDF, or share a link directly with students","Print it and hand it out in class only","Send the blank template for them to finish","Save it in the gradebook"]', 'Download it as an image or PDF, or share a link directly with students'),
    (7,  'In basic video editing, why do you trim the start and end of a raw clip?', '["To keep only the relevant part of the recording","To add a caption automatically","To make the file size larger","To convert the video into a PDF"]', 'To keep only the relevant part of the recording'),
    (8,  'A student is reviewing a lesson video with the sound off. What helps them follow along?', '["Captions on the video","A longer recording","A larger file size","A blank title slide"]', 'Captions on the video'),
    (9,  'According to the demonstration, lesson clips should be kept under what length to hold student attention better than one long recording?', '["Under 3 minutes","Under 30 minutes","About 1 hour","Length does not matter"]', 'Under 3 minutes'),
    (10, 'What should you do with large videos or images so they upload and load quickly?', '["Compress them","Add more text to them","Make them longer","Remove the captions"]', 'Compress them')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz6_week7_multimedia: seeded 10 questions on quiz %', v_quiz;
END $ict1_quiz6_week7_multimedia$;
