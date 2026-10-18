-- Expose the question format to staff editing tools so MC option-count rules
-- can be enforced without affecting matching or essay items.
CREATE OR REPLACE VIEW public.question_bank
WITH (security_invoker = true) AS
SELECT
  qq.id,
  qq.quiz_id,
  q.course_id,
  c.code AS course_code,
  qq.question,
  qq.options,
  qq.correct_answer,
  qq.position,
  qq.image_url,
  qq.lab_task,
  qq.required,
  qq.created_at,
  q.title AS quiz_title,
  q.created_at AS quiz_created_at,
  q.deleted_at AS quiz_deleted_at,
  qq.question_type
FROM public.quiz_questions qq
JOIN public.quizzes q ON q.id = qq.quiz_id
JOIN public.courses c ON c.id = q.course_id;

GRANT SELECT ON public.question_bank TO anon, authenticated, service_role;
