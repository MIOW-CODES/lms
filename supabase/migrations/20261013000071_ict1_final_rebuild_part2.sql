-- Course: ICT1 — FINAL EXAMINATION (Coverage: Weeks 1-7) — Part 2 (questions 51–100, Weeks 5–7)
--
-- Re-authored final-exam items (50 multiple-choice questions, 4 options each)
-- grounded strictly in ICT1's own Week 5–7 lecture slide texts:
--   * Week 5  Online Collaboration Tools (Gmail • Google Drive)
--   * Week 6  Learning Management Systems (Google Classroom • Moodle)
--   * Week 7  Multimedia in Education (Canva • Basic Video Editors)
-- Positions 51–67 = Week 5 (17 items), 68–84 = Week 6 (17 items),
-- 85–100 = Week 7 (16 items) — in that order. Application and scenario items
-- outnumber pure recall. No TVE100 content, no attachments, no lab tasks.
-- Questions 1–50 belong to another lane and are NEVER touched here.
--
-- UPSERT semantics (fully idempotent, safe to re-run):
--   * Course is resolved by code = 'ICT1', never a hard-coded uuid. If the course
--     is missing, the block raises a NOTICE and does nothing.
--   * The quiz is resolved by the exact title 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
--     (active = deleted_at IS NULL, oldest created_at wins). If it is missing, this
--     file creates it (duration_minutes = 60, question_count = 100, opens_at NULL,
--     closes_at = now() + interval '14 days', score_released/answer_key_released
--     false) so the file also works standalone. An existing quiz row's availability
--     and release settings are left untouched.
--   * Question replacement is scoped strictly to this lane's range:
--     DELETE ... WHERE quiz_id = v_quiz AND position BETWEEN 51 AND 100, then insert
--     positions 51..100. Positions 1–50 survive re-runs of this file untouched.
--     Re-running replaces the same 50 rows — never duplicates.
--
-- 50 questions, lab_task = false, required = false, image_url = NULL.

DO $ict1_final_rebuild_part2$
DECLARE
  v_course  uuid;
  v_quiz    uuid;
  v_deleted integer;
BEGIN
  -- ── Course lookup: ICT1 by its unique code, never a hard-coded uuid ───────
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_final_rebuild_part2: course ICT1 missing - nothing to do';
    RETURN;
  END IF;
  RAISE NOTICE 'ict1_final_rebuild_part2: resolved course ICT1 as %', v_course;

  -- ── Resolve the final-exam quiz by exact title (active, oldest wins) ─────
  SELECT id INTO v_quiz
    FROM public.quizzes
   WHERE course_id = v_course
     AND title = 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
     AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    -- Create it so this file works standalone.
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
        RAISE NOTICE 'ict1_final_rebuild_part2: quiz row vanished meanwhile - questions left untouched';
        RETURN;
      END IF;
      RAISE NOTICE 'ict1_final_rebuild_part2: quiz % appeared meanwhile - reusing it', v_quiz;
    ELSE
      RAISE NOTICE 'ict1_final_rebuild_part2: created quiz % (FINAL EXAMINATION, 60 minutes, 100 questions)', v_quiz;
    END IF;
  ELSE
    RAISE NOTICE 'ict1_final_rebuild_part2: quiz % exists - replacing positions 51-100 only', v_quiz;
  END IF;

  -- ── Replace ONLY this lane's range (positions 1-50 belong to another lane) ─
  DELETE FROM public.quiz_questions
   WHERE quiz_id = v_quiz AND position BETWEEN 51 AND 100;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RAISE NOTICE 'ict1_final_rebuild_part2: deleted % stale questions in range 51-100 on quiz %', v_deleted, v_quiz;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    -- ═══ Week 5 — Online Collaboration Tools (Gmail • Google Drive) — 51-67 ═══
    (51,  'Ms. Cruz must send a formal message to a student''s parent and, separately, work on the class report with two colleagues at the same time. Which combination of Week 5 tools fits both tasks?', '["Email for the parent message and shared docs for co-editing the report with the colleagues","Cloud Drive for the parent message and email for co-editing the report","Shared docs for the parent message and cloud drive for storing lesson materials","The checklist for the parent message and email for storing lesson materials"]', 'Email for the parent message and shared docs for co-editing the report with the colleagues'),
    (52,  'Why do email and cloud tools matter for teachers?', '["Teachers rarely work alone - email and cloud tools let them communicate with parents, co-plan with colleagues, and share materials instantly","They replace the need for lesson planning entirely","They are used only for sending a yearly school newsletter","They grade student papers automatically without any review"]', 'Teachers rarely work alone - email and cloud tools let them communicate with parents, co-plan with colleagues, and share materials instantly'),
    (53,  'Two teachers need to edit the same class report at the same time and see each other''s changes as they happen. Which Week 5 tool is the best fit?', '["Shared Docs - co-edit plans and reports in real time","Email - formal communication with parents and colleagues","Cloud Drive - store and share lesson materials anywhere","The checklist - graded on completion of each collaboration task"]', 'Shared Docs - co-edit plans and reports in real time'),
    (54,  'What is the main use of a cloud drive in teaching?', '["Store and share lesson materials anywhere","Track student attendance automatically","Replace classroom whiteboards with digital screens","Print handouts for the whole class"]', 'Store and share lesson materials anywhere'),
    (55,  'Which subject line follows the Week 5 advice on clear subject lines?', '["Grade 9 Science - Field Trip Consent Form Due Friday","Hello","URGENT!!! READ THIS NOW","[no subject line at all]"]', 'Grade 9 Science - Field Trip Consent Form Due Friday'),
    (56,  'Sir Diaz is sending a two-sentence note to a colleague and wants to skip the greeting and closing to save time. What does Week 5 advise?', '["Use a greeting, complete sentences, and a polite closing - even for quick notes","Write everything in capital letters so the short note stands out","Skip the greeting whenever the message is only a sentence or two","Use slang so the short message feels friendly"]', 'Use a greeting, complete sentences, and a polite closing - even for quick notes'),
    (57,  'Before sending an email with the field trip form attached, what should the teacher check?', '["That the files are attached and named clearly","That the subject line has been removed","That the attachments are sent later in a second email","That the files were renamed with random characters"]', 'That the files are attached and named clearly'),
    (58,  'Why should an email be reread before sending?', '["Email represents you professionally - reread for tone and typos","Proofreading makes the email arrive faster","Rereading lets the email carry larger attachments","Rereading removes the need for a polite closing"]', 'Email represents you professionally - reread for tone and typos'),
    (59,  'In the Google Drive demonstration, what is the first step in keeping materials organized?', '["Create folders by subject or class","Generate a shareable link for the whole class","Delete old files every day","Convert every file to PDF format"]', 'Create folders by subject or class'),
    (60,  'A teacher uploads a photo of a worksheet saved as IMG_2047.jpg. What does the demonstration recommend next?', '["Rename it using a clear, consistent format","Leave the camera filename exactly as it is","Hide the file from all collaborators","Compress the file into a zip archive"]', 'Rename it using a clear, consistent format'),
    (61,  'How does the demonstration give a colleague access to a file in Google Drive?', '["Click Share and add the colleague''s email to grant access","Forward the file to the colleague as an email attachment","Copy the file onto a USB drive","Rename the file with the colleague''s name"]', 'Click Share and add the colleague''s email to grant access'),
    (62,  'A teacher accidentally sets a class handout so everyone can edit it. What risk does the demonstration''s warning describe?', '["The wrong permission can accidentally let others edit - or block them from viewing at all","The wrong permission deletes the file permanently","The wrong permission prints the file automatically","The wrong permission converts the file into a spreadsheet"]', 'The wrong permission can accidentally let others edit - or block them from viewing at all'),
    (63,  'A colleague should be able to suggest feedback on your file but must not change its content. Which permission should you choose?', '["Commenter","Editor","Viewer","No permission - keep the file private"]', 'Commenter'),
    (64,  'You want to get a handout to the whole class quickly. What does the demonstration suggest?', '["Generate a shareable link for quick distribution to a class","Email the file to every student one by one","Print copies and hand them out in class","Ask each student to come and copy the file"]', 'Generate a shareable link for quick distribution to a class'),
    (65,  'How many students should form each group in the collaboration activity?', '["3-4 students","1 student working alone","5-6 students","The whole class in one group"]', '3-4 students'),
    (66,  'A teammate wrote a sentence you disagree with in the shared document. What is the proper digital etiquette?', '["Suggest changes or leave a comment instead of deleting a teammate''s work","Delete the sentence and rewrite it yourself","Overwrite the whole paragraph without telling anyone","Remove the teammate from the document"]', 'Suggest changes or leave a comment instead of deleting a teammate''s work'),
    (67,  'The group has finished editing its shared document. What does the checklist require before class ends?', '["Email the instructor the shared document link","Print the document and hand it in","Post the document on social media","Delete the document to free up storage"]', 'Email the instructor the shared document link'),
    -- ═══ Week 6 — Learning Management Systems (Google Classroom • Moodle) — 68-84 ═══
    (68,  'What is a Learning Management System (LMS) according to Week 6?', '["An online platform where teachers post materials, assignments, and grades - all in one place students can access anytime","A desktop program installed on each student''s laptop for typing documents","A printer server that shares handouts in the computer lab","A social media site where students chat with friends"]', 'An online platform where teachers post materials, assignments, and grades - all in one place students can access anytime'),
    (69,  'What three things does an LMS keep together in one place that students can access anytime?', '["Materials, assignments, and grades","Attendance, cafeteria menus, and club schedules","Only teacher lesson plans","Only student email accounts"]', 'Materials, assignments, and grades'),
    (70,  'Where in the LMS should a teacher post a PDF reading and the slide deck for tomorrow''s lesson?', '["Course Materials - readings, slides, and files in one place","The Gradebook - a running record of scores","Notifications - automatic alerts about due dates","The login screen"]', 'Course Materials - readings, slides, and files in one place'),
    (71,  'Students finished their worksheets at home. What does the LMS let them do with the work?', '["Submit the work directly online through the assignment","Change the course gradebook settings","Post announcements to the whole class","Install new software on school computers"]', 'Submit the work directly online through the assignment'),
    (72,  'The class trip schedule changed and every student must know at once. Which LMS feature fits?', '["Announcements - reach the whole class instantly","Gradebook - a running record of scores","Private messages sent to one student only","The login screen"]', 'Announcements - reach the whole class instantly'),
    (73,  'A teacher wants to see which students have and have not turned in their work. Which feature shows this?', '["Assignments & Submissions - teachers track who has and hasn''t submitted","Notifications - automatic alerts about new content","Announcements - reach the whole class instantly","The login screen"]', 'Assignments & Submissions - teachers track who has and hasn''t submitted'),
    (74,  'What are notifications in an LMS?', '["Automatic alerts when new content or due dates are posted","Weekly paper reports sent to parents","Pop-up advertisements inside the course","Password reminders from the system administrator"]', 'Automatic alerts when new content or due dates are posted'),
    (75,  'A student wants to see the score and teacher feedback on a paper submitted last week. Where should the student look?', '["The Gradebook - a running record of scores that both teacher and student can view","The announcements tab","The login screen","The notifications settings page"]', 'The Gradebook - a running record of scores that both teacher and student can view'),
    (76,  'Where does the LMS post the files, readings, and announcements that students see?', '["The Course Stream / Materials area","The Gradebook","The submission inbox only","The school''s internet settings"]', 'The Course Stream / Materials area'),
    (77,  'What is the first step in the LMS navigation demonstration?', '["Log in and locate your enrolled class or course","Submit an assignment before opening the class","Delete old assignments from the stream","Change the gradebook display settings"]', 'Log in and locate your enrolled class or course'),
    (78,  'You need to know what an assignment requires and when it is due. What should you do in the LMS?', '["Open the assignment and review its instructions and due date","Look only at the gradebook","Wait until the due date has passed","Check the login screen instead"]', 'Open the assignment and review its instructions and due date'),
    (79,  'What does the demonstration warn about uploading a file without pressing Turn in?', '["An unsubmitted file often shows as missing, even if it was uploaded","The file is automatically graded with full marks","The file is deleted from the LMS immediately","The teacher is not allowed to see the file"]', 'An unsubmitted file often shows as missing, even if it was uploaded'),
    (80,  'A student uploaded the homework file yesterday but forgot to press Turn in. What should the student expect and do?', '["The work may show as missing - open the assignment and turn it in properly","Nothing to do - the upload already counted as the submission","Email the file to a classmate instead","Wait for the gradebook to update by itself"]', 'The work may show as missing - open the assignment and turn it in properly'),
    (81,  'In the practical quiz, what counts as correctly submitting an assignment?', '["Correctly turn in a sample assignment, not just upload a file","Uploading any file to the course stream","Sending the file through email to the teacher","Opening the gradebook after class"]', 'Correctly turn in a sample assignment, not just upload a file'),
    (82,  'Google Classroom integrates directly with which tools?', '["Google Docs, Drive, and Gmail","Microsoft Word, Excel, and PowerPoint","Canva and basic video editors","Moodle and university servers"]', 'Google Docs, Drive, and Gmail'),
    (83,  'A university wants an LMS it can customize extensively across many departments. Which platform fits the Week 6 description?', '["Moodle","Google Classroom","Google Drive","Gmail"]', 'Moodle'),
    (84,  'A junior high teacher wants a simple, lightweight LMS that works with the Google tools the school already uses. Which platform fits the Week 6 description?', '["Google Classroom","Moodle","Google Drive","Gmail"]', 'Google Classroom'),
    -- ═══ Week 7 — Multimedia in Education (Canva • Basic Video Editors) — 85-100 ═══
    (85,  'Why does multimedia matter in teaching?', '["Images and short videos help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson","Multimedia replaces the teacher during class discussions","Videos are only for entertaining students during breaks","Images make all written instructions unnecessary"]', 'Images and short videos help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson'),
    (86,  'What do images do in a lesson?', '["Explain a concept visually in one glance","Replace all written instructions","Slow down the lesson pace","Only decorate the slides"]', 'Explain a concept visually in one glance'),
    (87,  'What do short videos do in a lesson?', '["Show a process or demonstration in motion","Print copies of the lesson for students","Grade student work automatically","Replace the need for any classroom activity"]', 'Show a process or demonstration in motion'),
    (88,  'A teacher with no design background worries that making graphics is only for professional designers. What does Week 7 say?', '["No experience is needed - simple design tools like Canva work without prior training","Advanced graphic design training is required first","Design tools can only be used on expensive computers","Teachers should hire a professional designer instead"]', 'No experience is needed - simple design tools like Canva work without prior training'),
    (89,  'What does Week 7 recommend as the first step when designing an instructional graphic in Canva?', '["Start from a ready-made template instead of a blank page","Always begin with a blank page to be original","Draw every element by hand first","Import a scanned photo of a paper sketch"]', 'Start from a ready-made template instead of a blank page'),
    (90,  'How can a teacher add visuals that fit the topic instantly in Canva?', '["Add free stock photos and icons that fit your topic","Pay for a professional photographer","Take screenshots from other people''s videos","Use only text with no images at all"]', 'Add free stock photos and icons that fit your topic'),
    (91,  'A poster designed in Canva is now needed as a slide for a presentation. Which feature should be used?', '["Resize & Crop - adjust dimensions for posters, slides, or social posts with one click","Stock Photos & Icons - add free images and icons that fit your topic","Export & Share - download as an image or PDF","Templates - start from a ready-made design"]', 'Resize & Crop - adjust dimensions for posters, slides, or social posts with one click'),
    (92,  'How can a finished Canva graphic be delivered to students?', '["Download it as an image or PDF, or share a link directly with students","Print it and post it on the classroom wall only","Save it only on a USB drive","Screenshot it and send it by text message"]', 'Download it as an image or PDF, or share a link directly with students'),
    (93,  'A raw lesson recording has 30 seconds of setup noise at the start and dead air at the end. What should the teacher do in the editor?', '["Trim the start and end to keep only the relevant part","Increase the volume of the whole recording","Export the recording without any changes","Convert the recording into a printed handout"]', 'Trim the start and end to keep only the relevant part'),
    (94,  'What is a text caption or title used for in the lesson video?', '["Introduce the topic of the lesson video","Show the file size of the video","Speed up the video playback","Replace the need to trim the clip"]', 'Introduce the topic of the lesson video'),
    (95,  'Who especially benefits from captions on a lesson video?', '["Students who are reviewing without sound","Only the teacher during editing","Students who never watch the video","The video editor software vendor"]', 'Students who are reviewing without sound'),
    (96,  'How long should a lesson video clip be to hold student attention better than one long recording?', '["Short - under 3 minutes","As long as possible, over 20 minutes","Exactly 10 minutes, always","Length does not matter at all"]', 'Short - under 3 minutes'),
    (97,  'Into what format should the final video be exported?', '["A format your LMS accepts","The largest file format available","An audio-only format","A format that works only offline"]', 'A format your LMS accepts'),
    (98,  'What does keeping it simple mean for an instructional image?', '["One clear message per image - avoid cramming in too much text or detail","Put as much text as possible on one slide","Use many colors and fonts together","Include every topic of the lesson in one image"]', 'One clear message per image - avoid cramming in too much text or detail'),
    (99,  'Why should the file size of images and videos be checked before sharing?', '["Compress large videos or images so they upload and load quickly","To make the files look more professional","To add more effects to the video","To increase the length of the video"]', 'Compress large videos or images so they upload and load quickly'),
    (100, 'The workshop is over and the rubric requires both deliverables. How must the finished image and video be submitted?', '["Both files exported and shared through the LMS before class ends","Only the image - the video stays on your device","Printed as photos and handed to the teacher","Kept private and shown on your own screen only"]', 'Both files exported and shared through the LMS before class ends')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_final_rebuild_part2: seeded 50 questions (positions 51-100, Weeks 5-7) on quiz %', v_quiz;
END $ict1_final_rebuild_part2$;
