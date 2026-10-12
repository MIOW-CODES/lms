-- Course: ICT1 — Quiz 7 — Week 7 (Multimedia in Education)
--
-- ICT1 Quiz 7 — 20 multiple-choice questions grounded strictly in the Week 7
-- lecture slides "Multimedia in Education".
-- Knowledge quiz only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1' (never a hard-coded uuid). If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'Quiz 7' exists on ICT1: keep the quiz row and
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
    RAISE NOTICE 'ict1_quiz7_week7: course code ICT1 not found — skipping Quiz 7';
    RETURN;
  END IF;

  -- Insert the quiz row only if 'Quiz 7' does not already exist on ICT1.
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, question_count, opens_at, closes_at,
     score_released, answer_key_released)
  SELECT v_course, 'Quiz 7', 10, 20, NULL::timestamptz, now() + interval '14 days', false, false
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
    UPDATE public.quizzes SET duration_minutes = 10, question_count = 20 WHERE id = v_quiz;
    RAISE NOTICE 'ict1_quiz7_week7: Quiz 7 exists (%) — replaced its question set', v_quiz;
  ELSE
    RAISE NOTICE 'ict1_quiz7_week7: created Quiz 7 (%)', v_quiz;
  END IF;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What is the Week 7 learning outcome?', '["Create simple images and videos for teaching","Use email and cloud tools for education","Navigate basic LMS features","Build a spreadsheet for recording student grades"]', 'Create simple images and videos for teaching'),
    (2,  'Which learning resources are used in Week 7 for creating multimedia?', '["Canva and basic video editors","Gmail and Google Drive","Google Classroom and Moodle","Microsoft Word and PowerPoint"]', 'Canva and basic video editors'),
    (3,  'What assessment tool is used in Week 7, and what is it graded on?', '["A project rubric, graded on the image and video created during the workshop","A checklist, graded on completion of each collaboration task","A practical quiz, graded on hands-on LMS navigation","A written examination, graded on multimedia history"]', 'A project rubric, graded on the image and video created during the workshop'),
    (4,  'According to Week 7, why do images and short videos matter in teaching?', '["They help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson","They replace the need for teachers in the classroom","They make lessons longer and more detailed","They are required by the school for every subject"]', 'They help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson'),
    (5,  'According to Week 7, what do images do for students?', '["Explain a concept visually in one glance","Replace all reading assignments","Record student attendance automatically","Grade student work instantly"]', 'Explain a concept visually in one glance'),
    (6,  'What are short videos especially good at showing students?', '["A process or demonstration in motion","A long reading assignment","A list of vocabulary words","A printable worksheet"]', 'A process or demonstration in motion'),
    (7,  'What does Week 7 say about simple design tools like Canva?', '["No experience is needed to use them","They require advanced graphic design training","They can only be used by professional designers","They cannot create images for teaching"]', 'No experience is needed to use them'),
    (8,  'When designing an instructional graphic in Canva, what does Week 7 recommend starting from?', '["A ready-made template instead of a blank page","A blank page with no design elements","A screenshot from another website","A photograph of the whiteboard"]', 'A ready-made template instead of a blank page'),
    (9,  'In Canva, what do Stock Photos & Icons let you add?', '["Free images and icons that fit your topic instantly","Paid subscriptions for every student","Background music for videos","Animations that play automatically"]', 'Free images and icons that fit your topic instantly'),
    (10, 'What does Resize & Crop let you do in Canva?', '["Adjust dimensions for posters, slides, or social posts with one click","Change the language of the text automatically","Add background music to a video","Print the design directly from Canva"]', 'Adjust dimensions for posters, slides, or social posts with one click'),
    (11, 'How can you get a finished Canva design to your students?', '["Download it as an image or PDF, or share a link directly with students","Email the Canva editor password to the whole class","Recreate the design by hand for each student","Save it only inside Canva with no way to share"]', 'Download it as an image or PDF, or share a link directly with students'),
    (12, 'What is the first step in basic video editing for a lesson clip?', '["Import a short raw video clip into the editor","Export the final video immediately","Add a text caption to every frame of the clip","Delete the clip and record it again"]', 'Import a short raw video clip into the editor'),
    (13, 'Right after importing a short raw video clip into the editor, what should you do next?', '["Trim the start and end to keep only the relevant part","Add as many transitions as possible","Export the video immediately","Rewrite the clip in another language"]', 'Trim the start and end to keep only the relevant part'),
    (14, 'Why add a text caption or title to a lesson video?', '["Captions help students who are reviewing without sound, and a title introduces the topic","They make the video file larger","They prevent students from skipping the video","They are required before a video can be exported"]', 'Captions help students who are reviewing without sound, and a title introduces the topic'),
    (15, 'According to Week 7, when should a simple transition be inserted between two clips?', '["Only if needed, between two clips","Between every single frame of the video","Never — transitions are not allowed in lesson videos","Only after the video has been exported"]', 'Only if needed, between two clips'),
    (16, 'What should the final lesson video be exported as?', '["A format your LMS accepts","The largest file size possible","A format that plays only on the teacher''s device","An audio-only file"]', 'A format your LMS accepts'),
    (17, 'What does Week 7 say about the length of lesson video clips?', '["Keep clips short — under 3 minutes holds student attention better than one long recording","Make videos as long as possible to cover everything","Videos should always be exactly 30 minutes","Length does not matter as long as the content is correct"]', 'Keep clips short — under 3 minutes holds student attention better than one long recording'),
    (18, 'What does the tip ''Keep It Simple'' mean for an instructional image?', '["One clear message per image — avoid cramming in too much text or detail","Use as many fonts and colors as possible","Add every detail about the topic on one slide","Leave the image mostly empty with no message"]', 'One clear message per image — avoid cramming in too much text or detail'),
    (19, 'What does the tip ''Check File Size'' mean?', '["Compress large videos or images so they upload and load quickly","Make files as large as possible for better quality","Rename the files to change their size","Delete all images before submitting"]', 'Compress large videos or images so they upload and load quickly'),
    (20, 'For the Week 7 project rubric, how must the finished image and video be submitted?', '["Both files exported and shared through the LMS before class ends","Handed in on a USB drive after class","Posted publicly on social media","Printed and pinned on the classroom bulletin board"]', 'Both files exported and shared through the LMS before class ends')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_quiz7_week7: Quiz 7 (%) now has 20 slide-based questions', v_quiz;
END $$;
