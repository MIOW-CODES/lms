CREATE TABLE IF NOT EXISTS public.quiz_question_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id uuid NOT NULL REFERENCES public.quiz_attempts(id) ON DELETE CASCADE,
  question_id uuid NOT NULL,
  old_correct boolean NOT NULL,
  new_correct boolean NOT NULL,
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 1 AND 1000),
  reviewer_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.quiz_question_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.quiz_question_reviews FROM anon, authenticated;
GRANT ALL ON public.quiz_question_reviews TO service_role;
CREATE INDEX IF NOT EXISTS quiz_question_reviews_attempt_idx ON public.quiz_question_reviews(attempt_id, created_at);
CREATE OR REPLACE FUNCTION public.review_attempt_question(
  p_attempt uuid, p_question uuid, p_correct boolean, p_expected boolean,
  p_reason text, p_actor uuid
) RETURNS void LANGUAGE plpgsql SET search_path=public AS $$
DECLARE attempt quiz_attempts%ROWTYPE; result jsonb; updated_results jsonb; raw integer;
BEGIN
  SELECT * INTO STRICT attempt FROM quiz_attempts WHERE id=p_attempt FOR UPDATE;
  SELECT value INTO result FROM jsonb_array_elements(attempt.results) WHERE value->>'id'=p_question::text;
  IF result IS NULL THEN RAISE EXCEPTION 'Question not found in attempt'; END IF;
  IF (result->>'correct')::boolean IS DISTINCT FROM p_expected THEN
    RAISE EXCEPTION 'This answer was already reviewed. Reload before applying.';
  END IF;
  IF p_correct=p_expected THEN RETURN; END IF;
  INSERT INTO quiz_question_reviews(attempt_id,question_id,old_correct,new_correct,reason,reviewer_id)
    VALUES(p_attempt,p_question,p_expected,p_correct,p_reason,p_actor);
  SELECT jsonb_agg(CASE WHEN value->>'id'=p_question::text THEN jsonb_set(value,'{correct}',to_jsonb(p_correct)) ELSE value END ORDER BY ord)
    INTO updated_results FROM jsonb_array_elements(attempt.results) WITH ORDINALITY AS t(value,ord);
  SELECT count(*) INTO raw FROM jsonb_array_elements(updated_results) WHERE (value->>'correct')::boolean;
  UPDATE quiz_attempts SET results=updated_results, raw_score=raw,
    score=greatest(0, raw-coalesce(attempt.integrity_penalty,0)) WHERE id=p_attempt;
END $$;
REVOKE ALL ON FUNCTION public.review_attempt_question(uuid,uuid,boolean,boolean,text,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.review_attempt_question(uuid,uuid,boolean,boolean,text,uuid) TO service_role;
