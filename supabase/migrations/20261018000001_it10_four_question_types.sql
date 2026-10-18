-- IT10 only: identify question formats and complete each active assessment's
-- bank with matching, essay, multiple-choice, and identification items.
-- Other courses keep their content, ordering, and question-bank behavior.
ALTER TABLE public.quiz_questions
  ADD COLUMN IF NOT EXISTS question_type text
  CHECK (question_type IN ('multiple_choice', 'matching', 'essay', 'identification'));

UPDATE public.quiz_questions qq
   SET question_type = CASE
     WHEN qq.correct_answer LIKE 'Rubric:%' THEN 'essay'
     WHEN jsonb_array_length(qq.options) > 0 THEN 'multiple_choice'
     ELSE 'identification'
   END
  FROM public.quizzes q JOIN public.courses c ON c.id = q.course_id
 WHERE qq.quiz_id = q.id
   AND upper(replace(c.code, ' ', '')) = 'IT10'
   AND q.deleted_at IS NULL
   AND qq.question_type IS NULL;

WITH targets AS (
  SELECT q.id, CASE
    WHEN q.title ILIKE '%Resistor%' THEN 'resistor'
    WHEN q.title ILIKE '%Programming%' THEN 'programming'
    ELSE 'arduino'
  END AS topic
  FROM public.quizzes q JOIN public.courses c ON c.id = q.course_id
  WHERE upper(replace(c.code, ' ', '')) = 'IT10' AND q.deleted_at IS NULL
), content(topic, kind, ordinal, prompt, choices, answer) AS (
  VALUES
  ('arduino', 'matching', 1, 'Column A: setup(). Match this Arduino function to its purpose.',
   '["Runs once when the board starts or resets", "Repeats continuously after initialization", "Configures a pin as an input or output"]', 'Runs once when the board starts or resets'),
  ('arduino', 'matching', 2, 'Column A: loop(). Match this Arduino function to its purpose.',
   '["Runs once when the board starts or resets", "Repeats continuously after initialization", "Configures a pin as an input or output"]', 'Repeats continuously after initialization'),
  ('arduino', 'matching', 3, 'Column A: pinMode(). Match this Arduino function to its purpose.',
   '["Runs once when the board starts or resets", "Repeats continuously after initialization", "Configures a pin as an input or output"]', 'Configures a pin as an input or output'),
  ('arduino', 'identification', 4, 'Identify the Arduino function used to set a digital output pin HIGH or LOW.', '[]', 'digitalWrite || digitalWrite()'),
  ('arduino', 'identification', 5, 'Identify the Arduino function used to read a digital input pin as HIGH or LOW.', '[]', 'digitalRead || digitalRead()'),
  ('arduino', 'essay', 6, 'Explain how an Arduino program uses setup() and loop() to control an LED safely through a current-limiting resistor.', '[]',
   'Rubric: Explain initialization, repeated program execution, and current limiting. | Keywords: initialization = setup, initialize; repetition = loop, repeat; protection = resistor, current'),
  ('resistor', 'matching', 1, 'Column A: First and second bands of a four-band resistor. Match the bands to their meaning.',
   '["The two significant digits", "The multiplier", "The tolerance"]', 'The two significant digits'),
  ('resistor', 'matching', 2, 'Column A: Third band of a four-band resistor. Match the band to its meaning.',
   '["The two significant digits", "The multiplier", "The tolerance"]', 'The multiplier'),
  ('resistor', 'matching', 3, 'Column A: Fourth band of a four-band resistor. Match the band to its meaning.',
   '["The two significant digits", "The multiplier", "The tolerance"]', 'The tolerance'),
  ('resistor', 'identification', 4, 'Identify the SI unit used to measure electrical resistance.', '[]', 'ohm || ohms || Ω'),
  ('resistor', 'identification', 5, 'Identify the resistor color that represents the digit zero.', '[]', 'black'),
  ('resistor', 'essay', 6, 'Explain how to determine the resistance and tolerance of a four-band resistor from its color bands.', '[]',
   'Rubric: Explain how the first two bands form significant digits, the third gives a multiplier, and the fourth gives tolerance. | Keywords: digits = digit, first, second; calculation = multiplier, multiply; tolerance = tolerance, percent'),
  ('programming', 'matching', 1, 'Column A: digitalRead(). Match this Arduino function to its purpose.',
   '["Reads HIGH or LOW from a digital input", "Writes HIGH or LOW to a digital output", "Pauses execution for a number of milliseconds"]', 'Reads HIGH or LOW from a digital input'),
  ('programming', 'matching', 2, 'Column A: digitalWrite(). Match this Arduino function to its purpose.',
   '["Reads HIGH or LOW from a digital input", "Writes HIGH or LOW to a digital output", "Pauses execution for a number of milliseconds"]', 'Writes HIGH or LOW to a digital output'),
  ('programming', 'matching', 3, 'Column A: delay(). Match this Arduino function to its purpose.',
   '["Reads HIGH or LOW from a digital input", "Writes HIGH or LOW to a digital output", "Pauses execution for a number of milliseconds"]', 'Pauses execution for a number of milliseconds'),
  ('programming', 'identification', 4, 'Identify the Arduino function that runs once when a sketch starts or the board resets.', '[]', 'setup || setup()'),
  ('programming', 'identification', 5, 'Identify the Arduino function that repeats continuously after setup() finishes.', '[]', 'loop || loop()'),
  ('programming', 'essay', 6, 'Explain how pinMode(), digitalWrite(), and delay() work together in an LED blink program.', '[]',
   'Rubric: Describe configuring the LED pin as an output, switching its state, and timing the changes. | Keywords: configuration = pinmode, output; switching = digitalwrite, high, low; timing = delay, millisecond, milliseconds')
)
INSERT INTO public.quiz_questions(quiz_id, question, options, correct_answer, position, required, question_type)
SELECT t.id, s.prompt, s.choices::jsonb, s.answer,
       coalesce((SELECT max(position) FROM public.quiz_questions old WHERE old.quiz_id = t.id), 0) + s.ordinal,
       true, s.kind
FROM targets t JOIN content s ON s.topic = t.topic
WHERE NOT EXISTS (
  SELECT 1 FROM public.quiz_questions existing
  WHERE existing.quiz_id = t.id AND existing.question_type = s.kind
);

-- Reserve one representative per format in every random draw. Existing
-- required picture-identification and lab tasks keep their fixed slots.
WITH representatives AS (
  SELECT DISTINCT ON (qq.quiz_id, qq.question_type) qq.id
  FROM public.quiz_questions qq
  JOIN public.quizzes q ON q.id = qq.quiz_id
  JOIN public.courses c ON c.id = q.course_id
  WHERE upper(replace(c.code, ' ', '')) = 'IT10' AND q.deleted_at IS NULL
  ORDER BY qq.quiz_id, qq.question_type, qq.position, qq.id
)
UPDATE public.quiz_questions SET required = true
WHERE id IN (SELECT id FROM representatives);
