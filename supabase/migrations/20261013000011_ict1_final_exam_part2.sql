-- Course: ICT1 — FINAL EXAMINATION (Coverage: Weeks 1-7) — Part 2 (questions 51–100, ICT1 Weeks 5–7)
--
-- Slide-grounded final-exam questions (50 multiple-choice items, 4 options each)
-- authored strictly from the Week 5–7 lecture slide texts:
--   * Week 5  Online Collaboration Tools (Gmail • Google Drive)
--   * Week 6  Learning Management Systems (Google Classroom • Moodle)
--   * Week 7  Multimedia in Education (Canva • Basic Video Editors)
-- Positions 51–67 = Week 5 (17 items), 68–84 = Week 6 (17 items),
-- 85–100 = Week 7 (16 items). Mix of recall + application, ordered by week
-- and slide order. Questions 1–50 (Weeks 1–4 material) are seeded by
-- 20261013000010_ict1_final_exam_part1.sql and are NEVER touched here.
--
-- UPSERT semantics (fully idempotent, safe to re-run):
--   * Course is resolved by code = 'ICT1' (title 'ICT 1 - LAB'), never a hard-coded
--     uuid. If the course is missing, the block raises a NOTICE and does nothing.
--   * The quiz is resolved by the exact title 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
--     (active = deleted_at IS NULL, oldest created_at wins). If it is missing, this
--     file creates it (duration_minutes = 60, question_count = 100, opens_at NULL,
--     closes_at = now() + 14 days, score_released/answer_key_released false) so the
--     file also works standalone without Part 1. An existing quiz row's availability
--     and release settings are left untouched.
--   * Question replacement is scoped strictly to this lane's range:
--     DELETE ... WHERE quiz_id = v_quiz AND position BETWEEN 51 AND 100, then insert
--     positions 51..100. Positions 1–50 belong to Part 1 and survive re-runs of this
--     file untouched. Re-running replaces the same 50 rows — never duplicates.
--
-- 50 questions, lab_task = false, required = false, image_url = NULL,
-- no attachments and NO lab_task questions.

DO $ict1_final_exam_part2$
DECLARE
  v_course  uuid;
  v_quiz    uuid;
  v_deleted integer;
BEGIN
  -- ── Course lookup: ICT1 by its unique code, never a hard-coded uuid ───────
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_final_exam_part2: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  -- ── Resolve the final-exam quiz by exact title (active, oldest wins) ─────
  SELECT id INTO v_quiz
    FROM public.quizzes
   WHERE course_id = v_course
     AND title = 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
     AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    -- Create it so this file works standalone (without Part 1).
    INSERT INTO public.quizzes
      (course_id, title, duration_minutes, question_count, opens_at, closes_at,
       score_released, answer_key_released)
    SELECT v_course, 'FINAL EXAMINATION (Coverage: Weeks 1-7)', 60, 100, NULL,
           now() + interval '14 days', false, false
    WHERE NOT EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE course_id = v_course
         AND title = 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
         AND deleted_at IS NULL
    )
    RETURNING id INTO v_quiz;

    IF v_quiz IS NULL THEN
      -- Race fallback: a row appeared meanwhile - reuse it instead of failing.
      SELECT id INTO v_quiz
        FROM public.quizzes
       WHERE course_id = v_course
         AND title = 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
         AND deleted_at IS NULL
       ORDER BY created_at
       LIMIT 1;
      IF v_quiz IS NULL THEN
        RAISE NOTICE 'ict1_final_exam_part2: quiz row vanished meanwhile - questions left untouched';
        RETURN;
      END IF;
      RAISE NOTICE 'ict1_final_exam_part2: quiz % appeared meanwhile - reusing it', v_quiz;
    ELSE
      RAISE NOTICE 'ict1_final_exam_part2: created quiz % (FINAL EXAMINATION, 60 minutes, 100 questions)', v_quiz;
    END IF;
  ELSE
    RAISE NOTICE 'ict1_final_exam_part2: quiz % exists - replacing positions 51-100 only', v_quiz;
  END IF;

  -- ── Replace ONLY this lane's range (positions 1-50 belong to Part 1) ─────
  DELETE FROM public.quiz_questions
   WHERE quiz_id = v_quiz AND position BETWEEN 51 AND 100;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RAISE NOTICE 'ict1_final_exam_part2: deleted % stale questions in range 51-100 on quiz %', v_deleted, v_quiz;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    -- ═══ Week 5 — Online Collaboration Tools (Gmail • Google Drive) — 51-67 ═══
    (51,  'Why do email and cloud tools matter for teachers?', '["Teachers rarely work alone - the tools let them communicate with parents, co-plan with colleagues, and share materials instantly","They replace the need for lesson planning entirely","They are used only for sending a yearly school newsletter","They grade student papers automatically without any review"]', 'Teachers rarely work alone - the tools let them communicate with parents, co-plan with colleagues, and share materials instantly'),
    (52,  'Which tool is described as formal communication with parents and colleagues?', '["Email","Cloud Drive","Shared Docs","The course stream"]', 'Email'),
    (53,  'What is the main use of a cloud drive in teaching?', '["Store and share lesson materials anywhere","Replace classroom whiteboards with digital screens","Track student attendance automatically","Print handouts for the whole class"]', 'Store and share lesson materials anywhere'),
    (54,  'What is the key benefit of shared docs mentioned in Week 5?', '["Co-edit plans and reports in real time","Lock files so nobody else can view them","Convert documents into printed handouts","Store only images and videos"]', 'Co-edit plans and reports in real time'),
    (55,  'Why should an email have a clear subject line?', '["It states the purpose so the reader knows what to expect before opening","It makes the email send faster","It replaces the need for a greeting","It hides the sender''s email address"]', 'It states the purpose so the reader knows what to expect before opening'),
    (56,  'Which practice shows a professional tone in an email?', '["Use a greeting, complete sentences, and a polite closing - even for quick notes","Write everything in capital letters to show enthusiasm","Leave out the greeting because the message is short","Use slang so the message feels friendly"]', 'Use a greeting, complete sentences, and a polite closing - even for quick notes'),
    (57,  'Before sending an email with attachments, what should you do?', '["Double-check that files are attached and named clearly","Remove the subject line to save space","Send it first and attach the files later","Rename the files with random characters"]', 'Double-check that files are attached and named clearly'),
    (58,  'Why is it important to proofread before sending an email?', '["Reread for tone and typos - email represents you professionally","Proofreading makes the email reach the recipient faster","It allows the email to carry larger attachments","It removes the need for a polite closing"]', 'Reread for tone and typos - email represents you professionally'),
    (59,  'In the Google Drive demonstration, what is the first step to keep materials organized?', '["Create folders by subject or class","Generate a shareable link for the whole class","Delete old files every day","Convert every file to PDF format"]', 'Create folders by subject or class'),
    (60,  'After uploading a file to Google Drive, what does the demonstration recommend?', '["Rename it using a clear, consistent format","Leave the camera filename exactly as it is","Hide the file from all collaborators","Compress the file into a zip archive"]', 'Rename it using a clear, consistent format'),
    (61,  'How do you grant a colleague access to your file in Google Drive?', '["Click Share and add the colleague''s email to grant access","Forward the file as an email attachment","Copy the file onto a USB drive","Rename the file with the colleague''s name"]', 'Click Share and add the colleague''s email to grant access'),
    (62,  'Why does the Drive demonstration warn you to watch the choice of sharing permission?', '["The wrong permission can accidentally let others edit - or block them from viewing at all","The wrong permission deletes the file permanently","The wrong permission prints the file automatically","The wrong permission converts the file into a spreadsheet"]', 'The wrong permission can accidentally let others edit - or block them from viewing at all'),
    (63,  'A colleague should be able to suggest feedback on your file but must not change its content. Which permission should you choose?', '["Commenter","Editor","Viewer","No permission - keep the file private"]', 'Commenter'),
    (64,  'You want to distribute a handout quickly to a whole class. What does the demonstration suggest?', '["Generate a shareable link for quick distribution to a class","Email the file to every student one by one","Print copies and hand them out in class","Ask each student to come and copy the file"]', 'Generate a shareable link for quick distribution to a class'),
    (65,  'How many students should form each group in the collaboration activity?', '["3–4 students","1 student working alone","5–6 students","The whole class in one group"]', '3–4 students'),
    (66,  'A teammate wrote a sentence you disagree with in the shared document. What is the proper digital etiquette?', '["Suggest changes or leave a comment instead of deleting a teammate''s work","Delete the sentence and rewrite it yourself","Overwrite the whole paragraph without telling anyone","Remove the teammate from the document"]', 'Suggest changes or leave a comment instead of deleting a teammate''s work'),
    (67,  'What must you do to submit the group''s shared document when the activity is done?', '["Email the instructor the shared document link","Print the document and hand it in","Post it on social media","Delete the document to free up storage"]', 'Email the instructor the shared document link'),
    -- ═══ Week 6 — Learning Management Systems (Google Classroom • Moodle) — 68-84 ═══
    (68,  'What is a Learning Management System (LMS)?', '["An online platform where teachers post materials, assignments, and grades - all in one place students can access anytime","A desktop program installed on each student''s laptop for typing documents","A printer server that shares handouts in the computer lab","A social media site where students chat with friends"]', 'An online platform where teachers post materials, assignments, and grades - all in one place students can access anytime'),
    (69,  'An LMS keeps which three things together in one place that students can access anytime?', '["Materials, assignments, and grades","Attendance, cafeteria menus, and club schedules","Only teacher lesson plans","Only student email accounts"]', 'Materials, assignments, and grades'),
    (70,  'What does the Course Materials area of an LMS contain?', '["Readings, slides, and files in one place","Only the teacher''s private notes","The school''s internet settings","Only games for break time"]', 'Readings, slides, and files in one place'),
    (71,  'What can students do through the Assignments feature?', '["Submit work directly online","Change the course gradebook settings","Post announcements to the whole class","Install new software on school computers"]', 'Submit work directly online'),
    (72,  'What is the purpose of announcements in an LMS?', '["Reach the whole class instantly","Send private messages to one student only","Store backup copies of every file","Track who has and has not submitted work"]', 'Reach the whole class instantly'),
    (73,  'Which LMS feature is where files, readings, and announcements are posted for students?', '["Course Stream / Materials","Gradebook","Notifications","The login screen"]', 'Course Stream / Materials'),
    (74,  'A teacher wants to find out which students have and have not turned in their work. Which LMS feature shows this?', '["Assignments and Submissions","Notifications","Announcements","The login screen"]', 'Assignments and Submissions'),
    (75,  'What are notifications in an LMS?', '["Automatic alerts when new content or due dates are posted","Weekly paper reports sent to parents","Pop-up advertisements inside the course","Password reminders from the system administrator"]', 'Automatic alerts when new content or due dates are posted'),
    (76,  'Which LMS feature is a running record of scores that both teacher and student can view?', '["Gradebook","Course Stream","Submissions","Announcements"]', 'Gradebook'),
    (77,  'What is the first step when navigating the LMS in the demonstration?', '["Log in and locate your enrolled class or course","Submit an assignment before opening the class","Delete old assignments from the stream","Change the gradebook display settings"]', 'Log in and locate your enrolled class or course'),
    (78,  'You need to check what an assignment requires and when it is due. What should you do in the LMS?', '["Open the assignment and review its instructions and due date","Look only at the gradebook","Wait until the due date has passed","Check the login screen instead"]', 'Open the assignment and review its instructions and due date'),
    (79,  'What does the LMS demonstration warn about uploading a file without pressing Turn in?', '["An unsubmitted file often shows as missing, even if it was uploaded","The file is automatically graded with full marks","The file is deleted from the LMS immediately","The teacher is not allowed to see the file"]', 'An unsubmitted file often shows as missing, even if it was uploaded'),
    (80,  'A student uploaded the homework file yesterday but forgot to press Turn in. What should the student expect and do?', '["The work may show as missing - open the assignment and turn it in properly","Nothing to do - the upload already counted as the submission","Email the file to a classmate instead","Wait for the gradebook to update by itself"]', 'The work may show as missing - open the assignment and turn it in properly'),
    (81,  'In the practical quiz, what counts as correctly submitting an assignment?', '["Correctly turn in a sample assignment, not just upload a file","Uploading any file to the course stream","Sending the file through email to the teacher","Opening the gradebook after class"]', 'Correctly turn in a sample assignment, not just upload a file'),
    (82,  'Google Classroom integrates directly with which tools?', '["Google Docs, Drive, and Gmail","Microsoft Word, Excel, and PowerPoint","Canva and basic video editors","Moodle and university servers"]', 'Google Docs, Drive, and Gmail'),
    (83,  'Which LMS platform is more customizable and feature-rich, and is common in universities and larger institutions?', '["Moodle","Google Classroom","Google Drive","Gmail"]', 'Moodle'),
    (84,  'How is Google Classroom described in the platform comparison?', '["Simple and lightweight","More customizable and feature-rich","Used only for editing videos","A cloud storage service for lesson materials"]', 'Simple and lightweight'),
    -- ═══ Week 7 — Multimedia in Education (Canva • Basic Video Editors) — 85-100 ═══
    (85,  'Why does multimedia matter in teaching?', '["Images and short videos help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson","Multimedia replaces the teacher during class discussions","Videos are only for entertaining students during breaks","Images make all written instructions unnecessary"]', 'Images and short videos help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson'),
    (86,  'What do images do in a lesson?', '["Explain a concept visually in one glance","Replace all written instructions","Slow down the lesson pace","Only decorate the slides"]', 'Explain a concept visually in one glance'),
    (87,  'What do short videos do in a lesson?', '["Show a process or demonstration in motion","Print copies of the lesson for students","Grade student work automatically","Replace the need for any classroom activity"]', 'Show a process or demonstration in motion'),
    (88,  'What is said about simple design tools like Canva?', '["No experience is needed to use tools like Canva","They require advanced graphic design training","They can only be used on expensive computers","They are made only for professional designers"]', 'No experience is needed to use tools like Canva'),
    (89,  'When starting an instructional graphic in Canva, what does the slide recommend?', '["Start from a ready-made template instead of a blank page","Always begin with a blank page to be original","Draw every element by hand first","Import a scanned photo of a paper sketch"]', 'Start from a ready-made template instead of a blank page'),
    (90,  'How can you add visuals that fit your topic instantly in Canva?', '["Add free stock photos and icons that fit your topic","Pay for a professional photographer","Take screenshots from other people''s videos","Use only text with no images at all"]', 'Add free stock photos and icons that fit your topic'),
    (91,  'You designed a poster in Canva and now need it sized for a slideshow. Which feature should you use?', '["Resize and Crop - adjust dimensions for posters, slides, or social posts with one click","Stock Photos and Icons","Export and Share","Templates"]', 'Resize and Crop - adjust dimensions for posters, slides, or social posts with one click'),
    (92,  'How can you deliver a finished Canva graphic to your students?', '["Download it as an image or PDF, or share a link directly with students","Print it and post it on the classroom wall only","Save it only on a USB drive","Screenshot it and send it by text message"]', 'Download it as an image or PDF, or share a link directly with students'),
    (93,  'Why trim the start and end of a video clip in the editing demonstration?', '["To keep only the relevant part of the recording","To make the file size larger","To add more background music","To lower the video resolution"]', 'To keep only the relevant part of the recording'),
    (94,  'In the video editing demonstration, what is a text caption or title used for?', '["Introduce the topic of the lesson video","Show the file size of the video","Speed up the video playback","Replace the need to trim the clip"]', 'Introduce the topic of the lesson video'),
    (95,  'Who especially benefits from captions on a lesson video?', '["Students who are reviewing without sound","Only the teacher during editing","Students who never watch the video","The video editor software vendor"]', 'Students who are reviewing without sound'),
    (96,  'How long should lesson video clips be to hold student attention better than one long recording?', '["Short - under 3 minutes","As long as possible, over 20 minutes","Exactly 10 minutes, always","Length does not matter at all"]', 'Short - under 3 minutes'),
    (97,  'Into what format should the final video be exported?', '["A format your LMS accepts","The largest file format available","An audio-only format","A format that works only offline"]', 'A format your LMS accepts'),
    (98,  'What does keeping it simple mean for an instructional image?', '["One clear message per image - avoid cramming in too much text or detail","Put as much text as possible on one slide","Use many colors and fonts together","Include every topic of the lesson in one image"]', 'One clear message per image - avoid cramming in too much text or detail'),
    (99,  'Why should you check the file size of your images and videos?', '["Compress large videos or images so they upload and load quickly","To make the files look more professional","To add more effects to the video","To increase the length of the video"]', 'Compress large videos or images so they upload and load quickly'),
    (100, 'How must the finished image and video be submitted for the project rubric?', '["Both files exported and shared through the LMS before class ends","Only the image - the video stays on your device","Printed as photos and handed to the teacher","Kept private and shown on your own screen only"]', 'Both files exported and shared through the LMS before class ends')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_final_exam_part2: seeded 50 questions (positions 51-100, Weeks 5-7) on quiz %', v_quiz;
END $ict1_final_exam_part2$;
