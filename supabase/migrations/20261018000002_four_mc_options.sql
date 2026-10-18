-- Keep every IT10 multiple-choice item consistent with the four-choice
-- worksheet layout. Existing three-choice items receive a neutral fourth
-- distractor; the answer key remains unchanged.
UPDATE public.quiz_questions qq
SET options = qq.options || '["None of the above"]'::jsonb
FROM public.quizzes q
JOIN public.courses c ON c.id = q.course_id
WHERE qq.quiz_id = q.id
  AND upper(replace(c.code, ' ', '')) = 'IT10'
  AND q.deleted_at IS NULL
  AND qq.question_type = 'multiple_choice'
  AND jsonb_array_length(qq.options) = 3;
