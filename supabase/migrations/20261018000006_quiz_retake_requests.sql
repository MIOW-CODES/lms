CREATE TABLE public.quiz_retake_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES public.profiles(id)
);

CREATE INDEX idx_quiz_retake_requests_quiz_pending
  ON public.quiz_retake_requests (quiz_id, requested_at DESC)
  WHERE status = 'pending';
CREATE UNIQUE INDEX uq_quiz_retake_requests_pending
  ON public.quiz_retake_requests (quiz_id, student_id)
  WHERE status = 'pending';

ALTER TABLE public.quiz_retake_requests ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.quiz_retake_requests TO service_role;

-- Approval and grant happen in one database transaction. Students with
-- historical submissions still receive one new attempt above their used count.
CREATE OR REPLACE FUNCTION public.grant_retake_on_request_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  base_attempts integer;
  used_attempts integer;
BEGIN
  IF OLD.status = 'pending' AND NEW.status = 'approved' THEN
    SELECT CASE WHEN allow_retake THEN max_attempts ELSE 1 END
      INTO base_attempts FROM public.quizzes WHERE id = NEW.quiz_id;
    SELECT count(*) INTO used_attempts FROM public.quiz_attempts
      WHERE quiz_id = NEW.quiz_id AND student_id = NEW.student_id;
    INSERT INTO public.quiz_retake_grants (quiz_id, student_id, extra_attempts, granted_by)
      VALUES (NEW.quiz_id, NEW.student_id, GREATEST(1, used_attempts + 1 - base_attempts), NEW.reviewed_by)
      ON CONFLICT (quiz_id, student_id) DO UPDATE
        SET extra_attempts = GREATEST(public.quiz_retake_grants.extra_attempts + 1,
                                      used_attempts + 1 - base_attempts),
            granted_by = NEW.reviewed_by;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER quiz_retake_request_approval_grants_attempt
  AFTER UPDATE OF status ON public.quiz_retake_requests
  FOR EACH ROW EXECUTE FUNCTION public.grant_retake_on_request_approval();
