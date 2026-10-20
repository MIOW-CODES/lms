-- Close the active ICT1 final exam after the class has finished taking it.
-- Resolve the course and exam by their unique code/title and stop without
-- changing anything if the production data is missing or ambiguous.
DO $ict1_close_final_exam$
DECLARE
  v_course_id uuid;
  v_course_count integer;
  v_exam_id uuid;
  v_exam_count integer;
  v_candidates text;
  v_close_at timestamptz := now() - interval '1 minute';
BEGIN
  SELECT count(*)
    INTO v_course_count
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'ICT1';

  IF v_course_count <> 1 THEN
    RAISE EXCEPTION 'ICT1 final close stopped: expected one ICT1 course, found %; no exam changed', v_course_count;
  END IF;
  SELECT id INTO v_course_id
    FROM public.courses
   WHERE upper(replace(btrim(code), ' ', '')) = 'ICT1';

  SELECT count(*), string_agg(format('%s (%s)', title, id), '; ' ORDER BY created_at)
    INTO v_exam_count, v_candidates
    FROM public.quizzes
   WHERE course_id = v_course_id
     AND title ILIKE '%final%'
     AND title ILIKE '%exam%'
     AND deleted_at IS NULL;

  IF v_exam_count <> 1 THEN
    SELECT string_agg(format('%s (%s)', title, id), '; ' ORDER BY created_at)
      INTO v_candidates
      FROM public.quizzes
     WHERE course_id = v_course_id
       AND (title ILIKE '%final%' OR title ILIKE '%exam%')
       AND deleted_at IS NULL;
    RAISE EXCEPTION 'ICT1 final close stopped: expected one active final exam, found %; candidates: %; no exam changed', v_exam_count, COALESCE(v_candidates, 'none');
  END IF;
  SELECT id INTO v_exam_id
    FROM public.quizzes
   WHERE course_id = v_course_id
     AND title ILIKE '%final%'
     AND title ILIKE '%exam%'
     AND deleted_at IS NULL;

  UPDATE public.quizzes
     SET closes_at = CASE
       WHEN closes_at IS NULL THEN v_close_at
       ELSE LEAST(closes_at, v_close_at)
     END
   WHERE id = v_exam_id;

  IF NOT EXISTS (
    SELECT 1 FROM public.quizzes
     WHERE id = v_exam_id
       AND closes_at <= now()
  ) THEN
    RAISE EXCEPTION 'ICT1 final close verification failed for quiz %', v_exam_id;
  END IF;

  RAISE NOTICE 'Closed ICT1 final exam %, course %, at %', v_exam_id, v_course_id, v_close_at;
END;
$ict1_close_final_exam$;
