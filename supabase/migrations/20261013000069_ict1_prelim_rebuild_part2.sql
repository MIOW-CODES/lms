-- Course: ICT1 — PRELIM EXAMINATION (Coverage: Weeks 1-7) — Part 2 (questions 51–100, Weeks 5–7)
--
-- Slide-grounded prelim-exam questions (50 multiple-choice items, 4 options each)
-- authored strictly from the ICT1 Week 5-7 lecture slide texts:
--   * Week 5  Online Collaboration Tools (Gmail • Google Drive)
--   * Week 6  Learning Management Systems (Google Classroom • Moodle)
--   * Week 7  Multimedia in Education (Canva • Basic Video Editors)
-- Positions 51-67 = Week 5 (17 items), 68-84 = Week 6 (17 items),
-- 85-100 = Week 7 (16 items). Mix of recall + application, ordered by week
-- and slide order. Questions 1-50 (Weeks 1-4 material) are seeded by the
-- companion Part 1 file and are NEVER touched here. No TVE100 content.
--
-- UPSERT semantics (fully idempotent, safe to re-run):
--   * Course is resolved by code = 'ICT1', never a hard-coded uuid. If the course
--     is missing, the block raises a NOTICE and does nothing.
--   * The quiz is resolved by the exact title 'PRELIM EXAMINATION (Coverage: Weeks 1-7)'
--     (active = deleted_at IS NULL, oldest created_at wins). If it is missing, this
--     file creates it (duration_minutes = 60, question_count = 80, opens_at NULL,
--     closes_at = now() + 14 days, score_released/answer_key_released false) so the
--     file also works standalone without Part 1. An existing quiz row's availability
--     and release settings are left untouched.
--   * Question replacement is scoped strictly to this lane's range:
--     DELETE ... WHERE quiz_id = v_quiz AND position BETWEEN 51 AND 100, then insert
--     positions 51..100. Positions 1-50 belong to Part 1 and survive re-runs of this
--     file untouched. Re-running replaces the same 50 rows - never duplicates.
--
-- 50 questions, lab_task = false, required = false, image_url = NULL,
-- no attachments and NO lab_task questions.

DO $ict1_prelim_rebuild_part2$
DECLARE
  v_course  uuid;
  v_quiz    uuid;
  v_deleted integer;
BEGIN
  -- ── Course lookup: ICT1 by its unique code, never a hard-coded uuid ───────
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_prelim_rebuild_part2: course ICT1 missing - nothing to do';
    RETURN;
  END IF;

  -- ── Resolve the prelim-exam quiz by exact title (active, oldest wins) ─────
  SELECT id INTO v_quiz
    FROM public.quizzes
   WHERE course_id = v_course
     AND title = 'PRELIM EXAMINATION (Coverage: Weeks 1-7)'
     AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    -- Create it so this file works standalone (without Part 1).
    INSERT INTO public.quizzes
      (course_id, title, duration_minutes, question_count, opens_at, closes_at,
       score_released, answer_key_released)
    SELECT v_course, 'PRELIM EXAMINATION (Coverage: Weeks 1-7)', 60, 80, NULL,
           now() + interval '14 days', false, false
    WHERE NOT EXISTS (
      SELECT 1 FROM public.quizzes
       WHERE course_id = v_course
         AND title = 'PRELIM EXAMINATION (Coverage: Weeks 1-7)'
         AND deleted_at IS NULL
    )
    RETURNING id INTO v_quiz;

    IF v_quiz IS NULL THEN
      -- Race fallback: a row appeared meanwhile - reuse it instead of failing.
      SELECT id INTO v_quiz
        FROM public.quizzes
       WHERE course_id = v_course
         AND title = 'PRELIM EXAMINATION (Coverage: Weeks 1-7)'
         AND deleted_at IS NULL
       ORDER BY created_at
       LIMIT 1;
      IF v_quiz IS NULL THEN
        RAISE NOTICE 'ict1_prelim_rebuild_part2: quiz row vanished meanwhile - questions left untouched';
        RETURN;
      END IF;
      RAISE NOTICE 'ict1_prelim_rebuild_part2: quiz % appeared meanwhile - reusing it', v_quiz;
    ELSE
      RAISE NOTICE 'ict1_prelim_rebuild_part2: created quiz % (PRELIM EXAMINATION, 60 minutes, 80 questions)', v_quiz;
    END IF;
  ELSE
    RAISE NOTICE 'ict1_prelim_rebuild_part2: quiz % exists - replacing positions 51-100 only', v_quiz;
  END IF;

  -- ── Replace ONLY this lane's range (positions 1-50 belong to Part 1) ─────
  DELETE FROM public.quiz_questions
   WHERE quiz_id = v_quiz AND position BETWEEN 51 AND 100;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RAISE NOTICE 'ict1_prelim_rebuild_part2: deleted % stale questions in range 51-100 on quiz %', v_deleted, v_quiz;

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    -- ═══ Week 5 — Online Collaboration Tools (Gmail • Google Drive) — 51-67 ═══
    (51,  'Which two tools are the learning resources for Week 5?', '["Gmail and Google Drive","Moodle and Google Classroom","Canva and a basic video editor","Microsoft Word and Microsoft Excel"]', 'Gmail and Google Drive'),
    (52,  'What is the Week 5 learning outcome?', '["Use email and cloud tools for education","Navigate basic LMS features","Create simple images and videos for teaching","Build a spreadsheet to record student grades"]', 'Use email and cloud tools for education'),
    (53,  'Which assessment tool is used for the Week 5 group activity?', '["Checklist","Practical Quiz","Project Rubric","Written examination"]', 'Checklist'),
    (54,  'How is the Week 5 collaboration work graded?', '["Graded on completion of each collaboration task during the group activity","Graded on a written examination at the end of the term","Graded on the number of emails sent to the instructor","Graded on the length of the shared document"]', 'Graded on completion of each collaboration task during the group activity'),
    (55,  'According to Week 5, what is email used for in school communication?', '["Formal communication with parents and colleagues","Editing images and videos for lessons","Storing lesson materials in the cloud","Posting grades inside the course stream"]', 'Formal communication with parents and colleagues'),
    (56,  'What does the Week 5 lesson say a cloud drive is used for?', '["Store and share lesson materials anywhere","Replace the classroom whiteboard entirely","Track student attendance automatically","Grade student papers without review"]', 'Store and share lesson materials anywhere'),
    (57,  'Which tool lets teachers co-edit plans and reports in real time?', '["Shared Docs","Email","The checklist","A printed handout"]', 'Shared Docs'),
    (58,  'Which part of an email states the purpose so the reader knows what to expect before opening?', '["The subject line","The attachment","The closing greeting","The signature block"]', 'The subject line'),
    (59,  'Which habit shows a professional tone even in a quick note?', '["Using a greeting, complete sentences, and a polite closing","Writing the message in capital letters","Leaving out the greeting because the message is short","Using slang so the message feels friendly"]', 'Using a greeting, complete sentences, and a polite closing'),
    (60,  'What should you double-check before sending an email with attachments?', '["That the files are attached and named clearly","That the subject line has been removed","That the files have random names","That the message has no greeting"]', 'That the files are attached and named clearly'),
    (61,  'Why is it important to proofread an email before sending it?', '["Because email represents you professionally","Because proofreading makes the email send faster","Because unproofread emails cannot carry attachments","Because proofreading replaces the subject line"]', 'Because email represents you professionally'),
    (62,  'In the Google Drive demonstration, what should folders be created by?', '["Subject or class","File size","The date the file was made","The name of the group member"]', 'Subject or class'),
    (63,  'How do you give a colleague access to a file in Google Drive?', '["Click Share and add the email of the colleague","Copy the file onto a USB drive","Print the file and hand it over","Rename the file with the name of the colleague"]', 'Click Share and add the email of the colleague'),
    (64,  'Which three sharing permissions are named in the Google Drive demonstration?', '["Viewer, Commenter, and Editor","Reader, Writer, and Admin","Owner, Guest, and Student","Viewer, Sender, and Printer"]', 'Viewer, Commenter, and Editor'),
    (65,  'You want classmates to be able to read your file but not change or comment on it. Which permission should you choose?', '["Viewer","Editor","Commenter","No permission - keep the file private"]', 'Viewer'),
    (66,  'What is the risk of choosing the wrong sharing permission in Google Drive?', '["It can accidentally let others edit - or block them from viewing at all","It permanently deletes the file from the drive","It converts the file into a spreadsheet","It prints the file automatically for the class"]', 'It can accidentally let others edit - or block them from viewing at all'),
    (67,  'What must each group do with the shared document when the collaboration activity is done?', '["Email the instructor the shared document link","Print the document and hand it in","Post it on social media","Delete the document to free up storage"]', 'Email the instructor the shared document link'),
    -- ═══ Week 6 — Learning Management Systems (Google Classroom • Moodle) — 68-84 ═══
    (68,  'Which two platforms are the learning resources for Week 6?', '["Google Classroom and Moodle","Gmail and Google Drive","Canva and a basic video editor","Microsoft Word and Microsoft Excel"]', 'Google Classroom and Moodle'),
    (69,  'What is the Week 6 learning outcome?', '["Navigate basic LMS features","Use email and cloud tools for education","Create simple images and videos for teaching","Build a spreadsheet to record student grades"]', 'Navigate basic LMS features'),
    (70,  'Which assessment tool is used in Week 6?', '["Practical Quiz","Checklist","Project Rubric","Written examination"]', 'Practical Quiz'),
    (71,  'How is the Week 6 practical quiz graded?', '["Graded on hands-on navigation tasks completed inside the LMS","Graded on a written essay about LMS history","Graded on the number of announcements posted","Graded on attendance during the exploration activity"]', 'Graded on hands-on navigation tasks completed inside the LMS'),
    (72,  'Where do teachers post materials, assignments, and grades so students can access them anytime?', '["A Learning Management System (LMS)","A shared spreadsheet in the cloud","A printed class newsletter","A social media page for the class"]', 'A Learning Management System (LMS)'),
    (73,  'What does the Course Materials area of an LMS contain?', '["Readings, slides, and files in one place","Only the private notes of the teacher","Only games for break time","The internet settings of the school"]', 'Readings, slides, and files in one place'),
    (74,  'What can students do through the Assignments feature of an LMS?', '["Submit work directly online","Change the settings of the gradebook","Install new software on school computers","Post announcements to the whole class"]', 'Submit work directly online'),
    (75,  'What is the purpose of announcements in an LMS?', '["Reach the whole class instantly","Send private messages to one student only","Store backup copies of every file","Track who has and has not submitted work"]', 'Reach the whole class instantly'),
    (76,  'What are notifications in an LMS?', '["Automatic alerts when new content or due dates are posted","Weekly paper reports sent to parents","Pop-up advertisements inside the course","Password reminders from the system administrator"]', 'Automatic alerts when new content or due dates are posted'),
    (77,  'Which LMS feature is a running record of scores that both teacher and student can view?', '["Gradebook","Course Stream","Announcements","The login screen"]', 'Gradebook'),
    (78,  'What is the first step when navigating the LMS in the demonstration?', '["Log in and locate your enrolled class or course","Submit an assignment before opening the class","Delete old assignments from the stream","Change the display settings of the gradebook"]', 'Log in and locate your enrolled class or course'),
    (79,  'How do you submit a file or text response in the LMS?', '["Through the assignment page","Through the login screen","By emailing a classmate","By printing it for the teacher"]', 'Through the assignment page'),
    (80,  'A student uploaded the homework file, but the LMS still shows the assignment as missing. What is the most likely reason?', '["The file was uploaded, but the assignment was never turned in","The file was too small to be accepted","The gradebook was checked too early","The student opened the class before logging in"]', 'The file was uploaded, but the assignment was never turned in'),
    (81,  'In the LMS demonstration, what is the gradebook checked for?', '["To see feedback and scores received","To upload a new assignment","To rename course materials","To send announcements to the class"]', 'To see feedback and scores received'),
    (82,  'How is Google Classroom described in the Week 6 platform comparison?', '["Simple and lightweight","More customizable and feature-rich","Used only for editing videos","A cloud storage service for lesson materials"]', 'Simple and lightweight'),
    (83,  'Google Classroom integrates directly with which tools?', '["Google Docs, Drive, and Gmail","Microsoft Word, Excel, and PowerPoint","Canva and basic video editors","Moodle and university servers"]', 'Google Docs, Drive, and Gmail'),
    (84,  'Which LMS platform is more customizable and feature-rich, and is common in universities and larger institutions?', '["Moodle","Google Classroom","Google Drive","Gmail"]', 'Moodle'),
    -- ═══ Week 7 — Multimedia in Education (Canva • Basic Video Editors) — 85-100 ═══
    (85,  'Which tools are the learning resources for Week 7?', '["Canva and basic video editors","Gmail and Google Drive","Google Classroom and Moodle","Microsoft Word and Microsoft Excel"]', 'Canva and basic video editors'),
    (86,  'What is the Week 7 learning outcome?', '["Create simple images and videos for teaching","Navigate basic LMS features","Use email and cloud tools for education","Build a spreadsheet to record student grades"]', 'Create simple images and videos for teaching'),
    (87,  'Which assessment tool is used in Week 7?', '["Project Rubric","Checklist","Practical Quiz","Written examination"]', 'Project Rubric'),
    (88,  'What does the Week 7 project rubric grade?', '["The image and video created during the workshop","The number of slides made during the lecture","The notes taken during the demonstration","The number of emails sent to the instructor"]', 'The image and video created during the workshop'),
    (89,  'Why does multimedia matter in teaching?', '["Images and short videos help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson","Multimedia replaces the teacher during class discussions","Videos are only for entertaining students during breaks","Images make all written instructions unnecessary"]', 'Images and short videos help students grasp ideas that are hard to explain in words alone, and keep attention during a lesson'),
    (90,  'What do images do in a lesson?', '["Explain a concept visually in one glance","Replace all written instructions","Slow down the lesson pace","Only decorate the slides"]', 'Explain a concept visually in one glance'),
    (91,  'What do short videos do in a lesson?', '["Show a process or demonstration in motion","Print copies of the lesson for students","Grade student work automatically","Replace the need for any classroom activity"]', 'Show a process or demonstration in motion'),
    (92,  'What is said about simple design tools like Canva?', '["No experience is needed to use tools like Canva","They require advanced graphic design training","They can only be used on expensive computers","They are made only for professional designers"]', 'No experience is needed to use tools like Canva'),
    (93,  'When starting an instructional graphic in Canva, what does the lesson recommend?', '["Start from a ready-made template instead of a blank page","Always begin with a blank page to be original","Draw every element by hand first","Import a scanned photo of a paper sketch"]', 'Start from a ready-made template instead of a blank page'),
    (94,  'How can you add visuals that fit your topic instantly in Canva?', '["Add free stock photos and icons that fit your topic","Pay for a professional photographer","Take screenshots from other videos","Use only text with no images at all"]', 'Add free stock photos and icons that fit your topic'),
    (95,  'Why is the start and end of a video clip trimmed during editing?', '["To keep only the relevant part","To make the file size larger","To add more background music","To lower the video resolution"]', 'To keep only the relevant part'),
    (96,  'What is a text caption or title used for in a lesson video?', '["Introduce the topic","Show the file size of the video","Speed up the video playback","Replace the need to trim the clip"]', 'Introduce the topic'),
    (97,  'Who especially benefits from captions on a lesson video?', '["Students who are reviewing without sound","Only the teacher during editing","Students who never watch the video","The video editor software vendor"]', 'Students who are reviewing without sound'),
    (98,  'According to the tips for effective multimedia, how long should videos be kept?', '["Aim for under 3-5 minutes so students stay focused from start to finish","As long as possible, over 20 minutes","Exactly 10 minutes, always","Length does not matter at all"]', 'Aim for under 3-5 minutes so students stay focused from start to finish'),
    (99,  'What does keeping it simple mean for an instructional image?', '["One clear message per image - avoid cramming in too much text or detail","Put as much text as possible on one image","Use many colors and fonts together","Include every topic of the lesson in one image"]', 'One clear message per image - avoid cramming in too much text or detail'),
    (100, 'How must the finished image and video be submitted for the project rubric?', '["Both files exported and shared through the LMS before class ends","Only the image, while the video stays on your device","Printed as photos and handed to the teacher","Kept private and shown on your own screen only"]', 'Both files exported and shared through the LMS before class ends')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_prelim_rebuild_part2: seeded 50 questions (positions 51-100, Weeks 5-7) on quiz %', v_quiz;
END $ict1_prelim_rebuild_part2$;
