-- ITE241 Advanced Digital Electronics — same source coverage as IT10.
-- Quizzes: 20 drawn items / 10 minutes. Exam: 50 MC items / 60 minutes.
-- Existing ITE241 questions are retained; exam items are filtered to MC and
-- the assessment configuration is normalized without touching other courses.
DO $$
DECLARE
  v_course uuid;
  v_exam uuid;
  v_q1 uuid;
  v_q2 uuid;
  v_q3 uuid;
  v_question_ids uuid[];
  v_items jsonb;
BEGIN
  SELECT id INTO v_course
    FROM public.courses
   WHERE upper(replace(code, ' ', '')) = 'ITE241'
      OR upper(regexp_replace(title, '[^a-zA-Z0-9]', '', 'g')) = 'ITE241ADVANCEDDIGITALELECTRONICS'
   ORDER BY (upper(replace(code, ' ', '')) = 'ITE241') DESC
   LIMIT 1;
  IF v_course IS NULL THEN
    RAISE NOTICE 'ITE241 seed skipped: create course ITE241 — Advanced Digital Electronics first';
    RETURN;
  END IF;

  -- The three quiz scopes follow the IT10 source pack: Arduino Part 2,
  -- Resistor Color Code, Programming with Arduino.
  SELECT id INTO v_q1 FROM public.quizzes WHERE course_id=v_course AND title='Quiz — Arduino Part 2' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_q2 FROM public.quizzes WHERE course_id=v_course AND title='Quiz — Resistor Color Code' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_q3 FROM public.quizzes WHERE course_id=v_course AND title='Quiz — Programming with Arduino' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1;
  IF v_q1 IS NULL THEN
    INSERT INTO public.quizzes(course_id,title,duration_minutes,allow_retake,max_attempts,retake_score_policy,question_count,opens_at,closes_at)
    VALUES(v_course,'Quiz — Arduino Part 2',10,true,0,'highest_score',20,NULL,now()+interval '14 days') RETURNING id INTO v_q1;
  ELSE UPDATE public.quizzes SET duration_minutes=10,question_count=20 WHERE id=v_q1; END IF;
  IF v_q2 IS NULL THEN
    INSERT INTO public.quizzes(course_id,title,duration_minutes,allow_retake,max_attempts,retake_score_policy,question_count,opens_at,closes_at)
    VALUES(v_course,'Quiz — Resistor Color Code',10,true,0,'highest_score',20,NULL,now()+interval '14 days') RETURNING id INTO v_q2;
  ELSE UPDATE public.quizzes SET duration_minutes=10,question_count=20 WHERE id=v_q2; END IF;
  IF v_q3 IS NULL THEN
    INSERT INTO public.quizzes(course_id,title,duration_minutes,allow_retake,max_attempts,retake_score_policy,question_count,opens_at,closes_at)
    VALUES(v_course,'Quiz — Programming with Arduino',10,true,0,'highest_score',20,NULL,now()+interval '14 days') RETURNING id INTO v_q3;
  ELSE UPDATE public.quizzes SET duration_minutes=10,question_count=20 WHERE id=v_q3; END IF;

  -- Mirror the existing IT10 source banks so ITE241 quizzes are immediately
  -- usable and keep identical material coverage. Preserve any authored target
  -- questions and append only stems that are not already present.
  INSERT INTO public.quiz_questions(quiz_id,question,options,correct_answer,position,image_url,lab_task,required)
  SELECT target.id,src.question,src.options,src.correct_answer,
         coalesce((SELECT max(position) FROM public.quiz_questions WHERE quiz_id=target.id),0)
           + row_number() OVER (PARTITION BY target.id ORDER BY src.position),
         src.image_url,src.lab_task,src.required
    FROM (VALUES (v_q1,'Quiz — Arduino Part 2'),(v_q2,'Quiz — Resistor Color Code'),(v_q3,'Quiz — Programming with Arduino')) AS mapping(target_id,source_title)
    JOIN public.quizzes target ON target.id=mapping.target_id
    JOIN public.quizzes source_quiz ON source_quiz.course_id=(SELECT id FROM public.courses WHERE code='IT10' LIMIT 1)
      AND source_quiz.title=mapping.source_title AND source_quiz.deleted_at IS NULL
    JOIN public.quiz_questions src ON src.quiz_id=source_quiz.id
   WHERE NOT EXISTS (
     SELECT 1 FROM public.quiz_questions existing
      WHERE existing.quiz_id=target.id AND lower(trim(existing.question))=lower(trim(src.question))
   );

  SELECT id INTO v_exam FROM public.quizzes WHERE course_id=v_course AND title='1st Quarter Exam' AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1;
  IF v_exam IS NULL THEN
    INSERT INTO public.quizzes(course_id,title,duration_minutes,allow_retake,max_attempts,retake_score_policy,question_count,opens_at,closes_at)
    VALUES(v_course,'1st Quarter Exam',60,true,0,'highest_score',50,NULL,now()+interval '14 days') RETURNING id INTO v_exam;
  ELSE UPDATE public.quizzes SET duration_minutes=60,question_count=50 WHERE id=v_exam; END IF;

  -- If no exam was seeded yet, copy the source-course MC bank before applying
  -- the ITE241-only multiple-choice and 50-item constraints.
  IF NOT EXISTS (SELECT 1 FROM public.quiz_questions WHERE quiz_id=v_exam) THEN
    SELECT array_agg(id ORDER BY position) INTO v_question_ids
      FROM (SELECT qq.id,qq.position FROM public.quiz_questions qq
            JOIN public.quizzes q ON q.id=qq.quiz_id
            JOIN public.courses c ON c.id=q.course_id
            WHERE c.code='IT10' AND q.title='1st Quarter Exam' AND q.deleted_at IS NULL
              AND jsonb_array_length(qq.options)>=2 ORDER BY qq.position LIMIT 50) src;
    IF coalesce(cardinality(v_question_ids),0) > 0 THEN
      INSERT INTO public.quiz_questions(quiz_id,question,options,correct_answer,position)
      SELECT v_exam,question,options,correct_answer,row_number() over(order by position)
        FROM public.quiz_questions WHERE id=ANY(v_question_ids);
    END IF;
  END IF;

  -- Exam is multiple-choice only. Retain at most the first 50 MC prompts.
  DELETE FROM public.quiz_questions
   WHERE quiz_id=v_exam
     AND (jsonb_typeof(options) <> 'array' OR jsonb_array_length(options) < 2 OR position > 50);

  -- The IT10 exam bank has 45 MC items. Top up the ITE241 exam with distinct
  -- MC questions from the same three source quizzes to make the required 50.
  WITH target_count AS (
    SELECT count(*)::integer AS n, coalesce(max(position),0)::integer AS max_position
      FROM public.quiz_questions WHERE quiz_id=v_exam AND jsonb_array_length(options)>=2
  ), candidates AS (
    SELECT DISTINCT ON (lower(trim(src.question))) src.question,src.options,src.correct_answer,src.position
      FROM public.courses it10
      JOIN public.quizzes source_quiz ON source_quiz.course_id=it10.id AND source_quiz.deleted_at IS NULL
      JOIN public.quiz_questions src ON src.quiz_id=source_quiz.id
     WHERE it10.code='IT10'
       AND source_quiz.title IN ('Quiz — Arduino Part 2','Quiz — Resistor Color Code','Quiz — Programming with Arduino')
       AND jsonb_array_length(src.options)>=2
       AND NOT EXISTS (SELECT 1 FROM public.quiz_questions existing WHERE existing.quiz_id=v_exam AND lower(trim(existing.question))=lower(trim(src.question)))
     ORDER BY lower(trim(src.question)),source_quiz.title,src.position
  ), numbered AS (
    SELECT candidates.*,row_number() OVER (ORDER BY position,question) AS rn FROM candidates
  ), chosen AS (
    SELECT numbered.* FROM numbered CROSS JOIN target_count
     WHERE numbered.rn <= greatest(0,50-target_count.n)
  )
  INSERT INTO public.quiz_questions(quiz_id,question,options,correct_answer,position)
  SELECT v_exam,chosen.question,chosen.options,chosen.correct_answer,target_count.max_position+chosen.rn
    FROM chosen CROSS JOIN target_count;

  -- Seed the ITE241 first-quarter TOS only when there is no teacher-authored row.
  IF NOT EXISTS (SELECT 1 FROM public.tos WHERE course_id=v_course AND quarter=1) THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
        'topic', title, 'no_of_items', question_count, 'cognitive_level', 'understanding',
        'quiz_id', id, 'note', CASE WHEN title='1st Quarter Exam' THEN '50 multiple-choice items · 60 minutes' ELSE '20 items · 10 minutes' END
      ) ORDER BY ord),'[]'::jsonb)
      INTO v_items
      FROM (VALUES (1,v_q1),(2,v_q2),(3,v_q3),(4,v_exam)) AS x(ord,id)
      JOIN public.quizzes q ON q.id=x.id;
    INSERT INTO public.tos(course_id,quarter,title,items)
    VALUES(v_course,1,'ITE241 — First Quarter Table of Specifications',v_items);
  END IF;
END $$;
