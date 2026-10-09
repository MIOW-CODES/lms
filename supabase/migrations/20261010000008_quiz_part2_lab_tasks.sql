-- Simulation tasks for Quiz — Arduino Part 2 (user request, 2026-10-09).
-- Two rubric-scored lab_task items using components proven in the exam's
-- Virtual Arduino Lab (LEDs, resistors, pushbutton, serial monitor).
-- required = true so they are pinned into every 20-of-26 draw.
-- Idempotent: skipped entirely if lab items already exist in the quiz.

DO $$
DECLARE
  v_course uuid;
  v_quiz uuid;
  v_next integer;
BEGIN
  SELECT id INTO v_course FROM public.courses
   WHERE title ILIKE '%IT 10%' OR title ILIKE '%IT10%'
      OR code ILIKE '%IT 10%' OR code ILIKE '%IT10%'
   ORDER BY created_at LIMIT 1;
  IF v_course IS NULL THEN
    RAISE EXCEPTION 'IT 10 course not found';
  END IF;

  SELECT id INTO v_quiz FROM public.quizzes
   WHERE course_id = v_course AND title = 'Quiz — Arduino Part 2' AND deleted_at IS NULL;
  IF v_quiz IS NULL THEN
    RAISE EXCEPTION 'Quiz — Arduino Part 2 not found';
  END IF;

  IF EXISTS (SELECT 1 FROM public.quiz_questions WHERE quiz_id = v_quiz AND lab_task) THEN
    RAISE NOTICE 'quiz already has lab_task items — skipping';
    RETURN;
  END IF;

  SELECT COALESCE(MAX(position), 0) + 1 INTO v_next FROM public.quiz_questions
   WHERE quiz_id = v_quiz;

  INSERT INTO public.quiz_questions
    (id, quiz_id, question, options, correct_answer, position, image_url, lab_task, required)
  VALUES
  (
    gen_random_uuid(),
    v_quiz,
    'Simulation Task A — Traffic Light (5 pts). In the Virtual Arduino Lab, build the traffic light: red, yellow, and green LEDs, each through a 220 Ω resistor, to digital pins 8, 9, and 10 with a common ground. Write a sketch that cycles red for 2 seconds, yellow for 1 second, and green for 2 seconds, repeating.',
    '[]'::jsonb,
    'Rubric: Three LEDs wired to pins 8 (red), 9 (yellow), and 10 (green), each with a 220 Ω resistor, common ground | Keywords: pinMode, digitalWrite, delay, 2000, 1000, red-yellow-green sequence, loop',
    v_next,
    NULL,
    true,
    true
  ),
  (
    gen_random_uuid(),
    v_quiz,
    'Simulation Task B — Button-Controlled LED with Serial Monitor (5 pts). In the Virtual Arduino Lab, wire a pushbutton to digital pin 2 (using INPUT_PULLUP) and an LED through a 220 Ω resistor to pin 13, common ground. Write a sketch that lights the LED while the button is pressed and prints the button state to the serial monitor.',
    '[]'::jsonb,
    'Rubric: Pushbutton on pin 2 configured INPUT_PULLUP, LED on pin 13; sketch reads the button each loop(), drives the LED from its state, and prints the state over Serial | Keywords: pinMode INPUT_PULLUP, digitalRead, digitalWrite, Serial.print, if statement, loop',
    v_next + 1,
    NULL,
    true,
    true
  );

  RAISE NOTICE 'inserted 2 required lab_task items at positions % and %', v_next, v_next + 1;
END $$;
