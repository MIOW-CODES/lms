-- Course: ICT1 — FINAL EXAMINATION (Coverage: Weeks 1-7) — Part 1 (questions 1–50, TVE100 Weeks 1–4)
--
-- ICT1 FINAL EXAMINATION — Part 1: 50 multiple-choice questions grounded strictly
-- in the TVE100 Week 1–4 lecture slides:
--   Week 1 — Introduction to the Course and the Philippine TVET System
--   Week 2 — The Teacher as a Professional
--   Week 3 — The Teacher and the Community
--   Week 4 — Understanding School Culture
-- Roughly 12–13 questions per week (Weeks 1–2: 13 each; Weeks 3–4: 12 each).
-- Knowledge exam only: no lab_task / simulation items, no attachments.
--
-- UPSERT semantics (fully idempotent — re-running never duplicates):
--   * Course resolved by code = 'ICT1', never a hard-coded uuid. If missing:
--     NOTICE + skip (never guess).
--   * If an active quiz titled 'FINAL EXAMINATION (Coverage: Weeks 1-7)' exists
--     on ICT1: reuse the quiz row, refresh duration_minutes = 60 and
--     question_count = 100.
--   * Otherwise: INSERT the quiz row (duration_minutes = 60,
--     question_count = 100, opens_at NULL, closes_at = now() + 14 days,
--     score_released = false, answer_key_released = false).
--   * Question replacement is scoped to this part's range ONLY:
--     DELETE positions 1–50, then insert positions 1..50. Positions 51–100 are
--     owned by the Part 2 migration and are never touched here.
DO $$
DECLARE
  v_course uuid;
  v_quiz   uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses WHERE code = 'ICT1';
  IF v_course IS NULL THEN
    RAISE NOTICE 'ict1_final_exam_part1: course code ICT1 not found — skipping FINAL EXAMINATION part 1';
    RETURN;
  END IF;
  RAISE NOTICE 'ict1_final_exam_part1: resolved course ICT1 (%)', v_course;

  -- Reuse an existing active FINAL EXAMINATION quiz row, else create one.
  SELECT id INTO v_quiz FROM public.quizzes
   WHERE course_id = v_course
     AND title = 'FINAL EXAMINATION (Coverage: Weeks 1-7)'
     AND deleted_at IS NULL
   ORDER BY created_at
   LIMIT 1;

  IF v_quiz IS NULL THEN
    INSERT INTO public.quizzes
      (course_id, title, duration_minutes, question_count, opens_at, closes_at,
       score_released, answer_key_released)
    VALUES
      (v_course, 'FINAL EXAMINATION (Coverage: Weeks 1-7)', 60, 100, NULL::timestamptz,
       now() + interval '14 days', false, false)
    RETURNING id INTO v_quiz;
    RAISE NOTICE 'ict1_final_exam_part1: created FINAL EXAMINATION quiz (%)', v_quiz;
  ELSE
    UPDATE public.quizzes
       SET duration_minutes = 60,
           question_count = 100
     WHERE id = v_quiz;
    RAISE NOTICE 'ict1_final_exam_part1: reusing FINAL EXAMINATION quiz (%) — refreshed duration_minutes=60, question_count=100', v_quiz;
  END IF;

  -- Replace ONLY positions 1–50 (owned by part 1); positions 51–100 untouched.
  DELETE FROM public.quiz_questions
   WHERE quiz_id = v_quiz AND position BETWEEN 1 AND 50;
  RAISE NOTICE 'ict1_final_exam_part1: cleared prior questions in positions 1–50';

  INSERT INTO public.quiz_questions
    (quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos, NULL, false, false
  FROM (VALUES
    (1,  'What does the acronym TVET stand for?', '["Technical and Vocational Education and Training","Technology and Vocational Employment Training","Technical and Vocational Enrichment Track","Trade and Vocational Education and Training"]', 'Technical and Vocational Education and Training'),
    (2,  'According to Week 1, what is TVET?', '["Education and training that develops occupational skills and competencies for specific trades, crafts, and technical careers — preparing learners for immediate, productive employment or entrepreneurship","A general education track focused on theory and college degrees","A scholarship program for graduating senior high school students","A government agency that certifies teachers"]', 'Education and training that develops occupational skills and competencies for specific trades, crafts, and technical careers — preparing learners for immediate, productive employment or entrepreneurship'),
    (3,  'Which curriculum characterizes technical-vocational education?', '["Competency-based, skills-oriented curriculum","Broad, theory-oriented curriculum","Research-based, thesis-oriented curriculum","General knowledge and cognitive skills curriculum"]', 'Competency-based, skills-oriented curriculum'),
    (4,  'Which educational track culminates in National Certificates (NC) via TESDA?', '["Technical-vocational education","General / academic education","Higher education degree programs","Basic education"]', 'Technical-vocational education'),
    (5,  'The Philippine education system is trifocalized — three agencies, three mandates. Which agency governs technical-vocational education, training, and skills certification?', '["TESDA — Technical Education & Skills Development Authority","DepEd — Department of Education","CHED — Commission on Higher Education","LGU — Local Government Unit"]', 'TESDA — Technical Education & Skills Development Authority'),
    (6,  'Which agency governs basic education — Kindergarten through Senior High School?', '["DepEd — Department of Education","TESDA — Technical Education & Skills Development Authority","CHED — Commission on Higher Education","The school board"]', 'DepEd — Department of Education'),
    (7,  'Which agency governs degree-granting higher education institutions and programs?', '["CHED — Commission on Higher Education","TESDA — Technical Education & Skills Development Authority","DepEd — Department of Education","NGOs & Professional Organizations"]', 'CHED — Commission on Higher Education'),
    (8,  'What is the legal basis of TESDA cited in Week 1?', '["Republic Act No. 7796, the Technical Education and Skills Development Act of 1994","Republic Act No. 10533, the K to 12 Act","Republic Act No. 7836, the Teachers Professionalization Act","Republic Act No. 9155, the Governance of Basic Education Act"]', 'Republic Act No. 7796, the Technical Education and Skills Development Act of 1994'),
    (9,  'A TVET graduate passes a competency assessment and receives a National Certificate. Which TESDA role is being performed?', '["Assessment & Certification","Standards Setting","Program Registration","Direct Training Provision"]', 'Assessment & Certification'),
    (10, 'Which TESDA role formulates competency standards and training regulations for TVET programs?', '["Standards Setting","Program Registration","Assessment & Certification","Direct Training Provision"]', 'Standards Setting'),
    (11, 'A TVET institution wants its new program registered and accredited nationwide. Which TESDA role should it approach?', '["Program Registration","Standards Setting","Assessment & Certification","Direct Training Provision"]', 'Program Registration'),
    (12, 'A barangay local government unit partners with a TVET school on skills training. Which key TVET stakeholder category does it represent?', '["Local Government Units (LGUs)","Industry Partners & Employers","NGOs & Professional Organizations","Technical-Vocational Institutions (TVIs)"]', 'Local Government Units (LGUs)'),
    (13, 'Compared with technical-vocational education, general / academic education is characterized by', '["A broad, theory-oriented curriculum that prepares learners for higher education","A competency-based, skills-oriented curriculum for immediate employment","Culminating in National Certificates (NC) via TESDA","An emphasis on hands-on, occupational competencies"]', 'A broad, theory-oriented curriculum that prepares learners for higher education'),
    (14, 'According to Week 2, what is professional identity?', '["How a TVET teacher understands their own role, values, and purpose — shaped over time by training, practice, ethics, and relationships with learners, colleagues, and community","A certificate issued by TESDA after passing an assessment","The salary grade assigned to a teacher by the institution","A list of competencies a learner must demonstrate before graduation"]', 'How a TVET teacher understands their own role, values, and purpose — shaped over time by training, practice, ethics, and relationships with learners, colleagues, and community'),
    (15, 'Command of the trade or occupational skill being taught refers to which pillar that shapes teacher identity?', '["Technical Mastery","Pedagogical Skill","Professional Ethics","Community Orientation"]', 'Technical Mastery'),
    (16, 'A new teacher can plan, deliver, and assess competency-based training effectively. Which pillar of teacher identity does this demonstrate?', '["Pedagogical Skill","Technical Mastery","Community Orientation","Continuous Improvement"]', 'Pedagogical Skill'),
    (17, 'Seeing oneself as a partner in the community''s development, not just a classroom instructor, describes which pillar of teacher identity?', '["Community Orientation","Technical Mastery","Pedagogical Skill","Professional Ethics"]', 'Community Orientation'),
    (18, 'Which role of a TVET teacher means guiding hands-on, competency-based learning rather than simply lecturing?', '["Facilitator","Mentor","Leader","Community Partner"]', 'Facilitator'),
    (19, 'A teacher coaches a struggling learner through skills development, confidence, and career readiness. Which role of a TVET teacher is being performed?', '["Mentor","Facilitator","Leader","Community Partner"]', 'Mentor'),
    (20, 'Which role of a TVET teacher involves modeling professionalism and setting direction within the training institution?', '["Leader","Facilitator","Mentor","Community Partner"]', 'Leader'),
    (21, 'A teacher connects the school with industry, LGUs, and the wider community it serves. Which role does this illustrate?', '["Community Partner","Facilitator","Mentor","Leader"]', 'Community Partner'),
    (22, 'In Week 2''s professional ethics, integrity means', '["Being honest and consistent in teaching, assessment, and dealings with learners and colleagues","Applying standards and grading competencies equitably, without bias or favoritism","Taking responsibility for learner outcomes, safety, and the quality of instruction","Valuing the dignity, culture, and circumstances of every learner and community member"]', 'Being honest and consistent in teaching, assessment, and dealings with learners and colleagues'),
    (23, 'A teacher applies standards and grades competencies equitably for every learner, without bias or favoritism. Which ethical principle is this?', '["Fairness","Integrity","Accountability","Respect"]', 'Fairness'),
    (24, 'Taking responsibility for learner outcomes, safety, and the quality of instruction is which core ethical principle?', '["Accountability","Integrity","Fairness","Respect"]', 'Accountability'),
    (25, 'What does competency-based TVET measure?', '["What a learner can actually do against a defined standard — not seat time","The number of hours a learner spends in the workshop","How well a learner memorizes trade theories","The learner''s attendance and class participation record"]', 'What a learner can actually do against a defined standard — not seat time'),
    (26, 'Which competency area covers core work-readiness skills — communication, teamwork, safety, and professionalism?', '["Basic Competencies","Common Competencies","Core / Technical Competencies","Training Methodology"]', 'Basic Competencies'),
    (27, 'According to Week 3, a TVET school''s effectiveness depends on what kind of relationship with its community?', '["An ongoing, two-way relationship with learners'' families, employers, local government, and civic groups","A one-way relationship where the school only issues announcements","An occasional relationship activated only during graduation","A purely financial relationship with industry sponsors"]', 'An ongoing, two-way relationship with learners'' families, employers, local government, and civic groups'),
    (28, 'In the school-community relationship, which of the following does the community give to the school?', '["Real-world context and industry needs","Trained, work-ready graduates","A venue for community learning and events","Technical expertise and consultation"]', 'Real-world context and industry needs'),
    (29, 'A TVET teacher connects the classroom to real community and industry needs. Which community-leadership role is this?', '["Bridge","Advocate","Model","Resource"]', 'Bridge'),
    (30, 'Which community-leadership role means speaking up for learners'' and the community''s interests within the institution?', '["Advocate","Bridge","Model","Resource"]', 'Advocate'),
    (31, 'Which community-leadership role involves demonstrating civic responsibility and professionalism the community can trust?', '["Model","Advocate","Bridge","Resource"]', 'Model'),
    (32, 'A teacher shares technical knowledge and skills to support community initiatives. Which community-leadership role does this illustrate?', '["Resource","Bridge","Advocate","Model"]', 'Resource'),
    (33, 'What is the correct sequence of steps in understanding community needs?', '["Gather Data → Engage Stakeholders → Identify Gaps → Set Priorities","Set Priorities → Gather Data → Identify Gaps → Engage Stakeholders","Identify Gaps → Set Priorities → Gather Data → Engage Stakeholders","Engage Stakeholders → Set Priorities → Gather Data → Identify Gaps"]', 'Gather Data → Engage Stakeholders → Identify Gaps → Set Priorities'),
    (34, 'After talking with local employers, LGUs, parents, and learners, a school compares its current programs and services against what the community actually needs. Which needs-assessment step is this?', '["Identify Gaps","Gather Data","Engage Stakeholders","Set Priorities"]', 'Identify Gaps'),
    (35, 'Advocating so training opportunities reach marginalized and underserved learners is an example of which aspect of a teacher''s social responsibility?', '["Equitable Access","Ethical Influence","Local Development","Sustainability"]', 'Equitable Access'),
    (36, 'Using one''s position to model integrity and civic-mindedness in the community refers to', '["Ethical Influence","Equitable Access","Local Development","Sustainability"]', 'Ethical Influence'),
    (37, 'At which level of community participation do the school and community co-design programs and share decision-making?', '["Collaborate","Inform","Consult","Involve"]', 'Collaborate'),
    (38, 'A community organization leads its own livelihood initiative, with the TVET school supporting their efforts. Which level of community participation is this?', '["Empower","Collaborate","Consult","Inform"]', 'Empower'),
    (39, 'According to Week 4, what is school culture?', '["The shared set of norms, values, beliefs, traditions, and practices that shape how people in a school think, feel, and act","The official policy manual published by the school administration","The physical facilities and equipment of a TVET institution","The list of subjects and competencies in the curriculum"]', 'The shared set of norms, values, beliefs, traditions, and practices that shape how people in a school think, feel, and act'),
    (40, 'Which statement about school culture is supported by Week 4?', '["Culture is learned and shared, not individual","Culture is created individually by the school principal","Culture is expressed only through policy documents","Culture cannot support or undermine a school''s official goals"]', 'Culture is learned and shared, not individual'),
    (41, 'The building, uniforms, ceremonies, posted rules, and how people greet each other belong to which level of culture?', '["Artifacts","Espoused Values","Underlying Assumptions","Shared Beliefs"]', 'Artifacts'),
    (42, 'Mission statements, codes of conduct, and publicly declared priorities belong to which level of culture?', '["Espoused Values","Artifacts","Underlying Assumptions","Practices"]', 'Espoused Values'),
    (43, 'A reviewer notices deeply held, often unconscious beliefs that truly drive behavior and are rarely questioned openly. Which level of culture is being described?', '["Underlying Assumptions","Artifacts","Espoused Values","Traditions"]', 'Underlying Assumptions'),
    (44, 'The unwritten rules for how people are expected to behave and interact are called', '["Norms","Values","Beliefs","Practices"]', 'Norms'),
    (45, 'What the school community collectively considers important or worthwhile refers to', '["Values","Norms","Traditions","Practices"]', 'Values'),
    (46, 'Shared convictions about learners, teaching, and what good training looks like are', '["Beliefs","Norms","Values","Artifacts"]', 'Beliefs'),
    (47, 'Recurring events and rituals that reinforce a sense of identity and belonging are', '["Traditions","Norms","Values","Beliefs"]', 'Traditions'),
    (48, 'The routine, everyday ways of doing work — from instruction to decision-making — are', '["Practices","Traditions","Norms","Values"]', 'Practices'),
    (49, 'Which of the following is an example of invisible culture in a TVET school?', '["Unspoken assumptions about learner potential","Facilities, workshop layout, and equipment","Uniforms, signage, and displayed accomplishments","Ceremonies, assemblies, and recognition events"]', 'Unspoken assumptions about learner potential'),
    (50, 'A healthy school culture makes it easier to adopt new technologies, standards, and teaching methods. Why does school culture matter in TVET in this case?', '["Change Readiness","Learning Quality","Staff Retention","Industry Trust"]', 'Change Readiness')
  ) AS q(pos, question, options, correct_answer);

  RAISE NOTICE 'ict1_final_exam_part1: inserted 50 slide-based questions at positions 1–50 for FINAL EXAMINATION (%)', v_quiz;
END $$;
