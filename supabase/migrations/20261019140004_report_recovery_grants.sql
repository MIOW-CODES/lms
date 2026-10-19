-- A retry of report maintenance must never grant a second recovery attempt.
CREATE TABLE IF NOT EXISTS public.feedback_recovery_grants (
  report_id uuid PRIMARY KEY REFERENCES public.feedback_reports(id),
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id),
  student_id uuid NOT NULL REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.feedback_recovery_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.feedback_recovery_grants FROM anon, authenticated;
GRANT ALL ON public.feedback_recovery_grants TO service_role;
CREATE OR REPLACE FUNCTION public.grant_report_recovery(p_report uuid,p_quiz uuid,p_student uuid)
RETURNS boolean LANGUAGE plpgsql SET search_path=public AS $$
DECLARE inserted uuid;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM feedback_reports WHERE id=p_report AND reporter_id=p_student) THEN
    RAISE EXCEPTION 'Report does not belong to this student';
  END IF;
  INSERT INTO feedback_recovery_grants(report_id,quiz_id,student_id) VALUES(p_report,p_quiz,p_student)
    ON CONFLICT(report_id) DO NOTHING RETURNING report_id INTO inserted;
  IF inserted IS NULL THEN RETURN false; END IF;
  INSERT INTO quiz_retake_grants(quiz_id,student_id,extra_attempts) VALUES(p_quiz,p_student,1)
    ON CONFLICT(quiz_id,student_id) DO UPDATE SET extra_attempts=quiz_retake_grants.extra_attempts+1;
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.grant_report_recovery(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.grant_report_recovery(uuid,uuid,uuid) TO service_role;
