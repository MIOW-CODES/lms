-- Narrow content correction for the reported light-intensity identification.
-- Accept established equivalent wording only; do not broaden every question.
UPDATE public.quiz_questions AS question
SET correct_answer='light||brightness||light intensity||light level||amount of light||how bright it is'
FROM public.quizzes AS quiz, public.courses AS course
WHERE question.quiz_id=quiz.id AND quiz.course_id=course.id
  AND upper(btrim(course.code))='IT10'
  AND question.question='A light-dependent resistor changes its resistance based on ______.'
  AND question.correct_answer='light||brightness||light intensity';
