-- Course: ICT1 — Quiz 7 — Week 7 (Slide: WEEK 7 Multimedia in Education Canva • Basic Video Editors)
--
-- ICT1 Quiz 7 — 10 multiple-choice questions grounded strictly in the Week 7
-- lecture slides "Multimedia in Education" (Canva / Basic Video Editors).
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If missing: NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 7' exists on ICT1: keep the quiz row, hard
--     delete its old quiz_questions rows, insert this slide-based set, and
--     refresh duration_minutes = 20 / question_count = 10. opens_at, closes_at,
--     score_released and answer_key_released are left untouched so a teacher's
--     availability/release state survives re-seeding.
--   * Otherwise: insert the quiz + its questions (duration 20, opens_at NULL,
--     closes_at now() + 14 days, score/answer key not released).
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
    RAISE NOTICE 'ict1_quiz7_week7: course code ICT1 not found — skipping Quiz 7';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 7' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 7', 20, 10, NULL::timestamptz, now() + interval '14 days', false, false
  WHERE NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 7' AND deleted_at IS NULL
  )
  RETURNING id INTO v_quiz;

  IF v_quiz IS NULL THEN
    -- Quiz already exists: replace its question set in place.
    SELECT id INTO v_quiz FROM public.quizzes
     WHERE course_id = v_course AND title = 'Quiz 7' AND deleted_at IS NULL
     ORDER BY created_at
     LIMIT 1;
    DELETE FROM public.quiz_questions WHERE quiz_id = v_quiz;
    UPDATE public.quizzes SET duration_minutes = 20, question_count = 10 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz7_week7: Quiz 7 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz7_week7: created Quiz 7 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'According to Week 7, why do images and short videos matter in teaching?', '["They help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson","They replace the need for teachers in the classroom","They make lessons longer and more detailed","They are required by the school for every subject"]', 'They help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson'),
    (2,  'What are short videos especially good at showing students?', '["A process or demonstration in motion","A long reading assignment","A list of vocabulary words","A printable worksheet"]', 'A process or demonstration in motion'),
    (3,  'When designing an instructional graphic in Canva, what does Week 7 recommend starting from?', '["A ready-made template instead of a blank page","A blank page with no design elements","A screenshot from another website","A photograph of the whiteboard"]', 'A ready-made template instead of a blank page'),
    (4,  'What does Resize & Crop let you do in Canva?', '["Adjust dimensions for posters, slides, or social posts with one click","Change the language of the text automatically","Add background music to a video","Print the design directly from Canva"]', 'Adjust dimensions for posters, slides, or social posts with one click'),
    (5,  'How can you get a finished Canva design to your students?', '["Download it as an image or PDF, or share a link directly with students","Email the Canva editor password to the whole class","Recreate the design by hand for each student","Save it only inside Canva with no way to share"]', 'Download it as an image or PDF, or share a link directly with students'),
    (6,  'Right after importing a short raw video clip into the editor, what should you do next?', '["Trim the start and end to keep only the relevant part","Add as many transitions as possible","Export the video immediately","Rewrite the clip in another language"]', 'Trim the start and end to keep only the relevant part'),
    (7,  'Why add a text caption or title to a lesson video?', '["Captions help students who are reviewing without sound, and a title introduces the topic","They make the video file larger","They prevent students from skipping the video","They are required before a video can be exported"]', 'Captions help students who are reviewing without sound, and a title introduces the topic'),
    (8,  'What does Week 7 say about the length of lesson video clips?', '["Keep clips short — under 3 minutes holds student attention better than one long recording","Make videos as long as possible to cover everything","Videos should always be exactly 30 minutes","Length does not matter as long as the content is correct"]', 'Keep clips short — under 3 minutes holds student attention better than one long recording'),
    (9,  'What does the tip ''Keep It Simple'' mean for an instructional image?', '["One clear message per image — avoid cramming in too much text or detail","Use as many fonts and colors as possible","Add every detail about the topic on one slide","Leave the image mostly empty with no message"]', 'One clear message per image — avoid cramming in too much text or detail'),
    (10, 'For the Week 7 project rubric, how must the finished image and video be submitted?', '["Both files exported and shared through the LMS before class ends","Handed in on a USB drive after class","Posted publicly on social media","Printed and pinned on the classroom bulletin board"]', 'Both files exported and shared through the LMS before class ends')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz7_week7: Quiz 7 (%) now has 10 slide-based questions', v_quiz;
END $$;
