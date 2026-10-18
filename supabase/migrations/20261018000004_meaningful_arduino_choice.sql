-- Replace the temporary fourth-choice placeholder with a meaningful distractor
-- for Arduino multiple-choice questions.
UPDATE quiz_questions AS qq
SET options = (qq.options - (jsonb_array_length(qq.options) - 1)) || '["microcontroller-based"]'::jsonb
FROM quizzes AS q
JOIN courses AS c ON c.id = q.course_id
WHERE qq.quiz_id = q.id
  AND c.code = 'IT10'
  AND q.title ILIKE '%Arduino%'
  AND qq.question_type = 'multiple_choice'
  AND jsonb_array_length(qq.options) = 4
  AND qq.options->>-1 = 'None of the above';
