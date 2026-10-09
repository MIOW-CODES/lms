-- Quizzes for the two reconstructed IT 10 materials: Arduino Part 1 handout
-- and Laboratory Activity 1 (Blinking LED). Same pattern as the source quizzes:
-- 24-item bank, question_count=20 (unseen-first draw per attempt), 10 minutes,
-- unlimited retakes, 14-day window. Re-runnable via soft-delete by title.
DO $$
DECLARE
  v_course uuid;
  v_quiz uuid;
BEGIN
  SELECT id INTO v_course FROM public.courses
   WHERE title ILIKE '%IT 10%' OR title ILIKE '%IT10%'
      OR code ILIKE '%IT 10%' OR code ILIKE '%IT10%'
   ORDER BY created_at
   LIMIT 1;
  IF v_course IS NULL THEN
    RAISE EXCEPTION 'IT 10 course not found — create the course before seeding quizzes';
  END IF;

  ------------------------------------------------------------------ Quiz: Part 1
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz — Arduino Part 1' AND deleted_at IS NULL;
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz — Arduino Part 1', 10, true, 0, 'highest_score', 20,
          NULL, now() + interval '14 days')
  RETURNING id INTO v_quiz;
  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'Arduino is an ______ electronic prototyping platform.', '["open-source","closed-source","paid-only"]', 'open-source'),
    (2,  'Arduino consists of a programmable circuit board and the', '["Arduino IDE","Serial Monitor","breadboard only"]', 'Arduino IDE'),
    (3,  'On the Arduino UNO, programs are uploaded from the PC through the', '["USB port","power jack","reset button"]', 'USB port'),
    (4,  'The reset button on the UNO', '["restarts the program from setup()","erases the sketch","clears the serial monitor"]', 'restarts the program from setup()'),
    (5,  'The "brain" of the Arduino UNO that stores and runs the sketch is the', '["microcontroller (ATmega328P)","USB chip only","voltage regulator"]', 'microcontroller (ATmega328P)'),
    (6,  'The UNO has how many digital pins (0–13)?', '["14","6","20"]', '14'),
    (7,  'The UNO has how many analog input pins?', '["6 (A0–A5)","14","8"]', '6 (A0–A5)'),
    (8,  'Analog pins are used to', '["read varying voltage levels from sensors","send only ON/OFF signals","power motors directly"]', 'read varying voltage levels from sensors'),
    (9,  'analogRead() on the UNO returns values in the range', '["0 to 1023","0 to 255","0 to 5"]', '0 to 1023'),
    (10, 'The power pins on the UNO header include', '["5V, 3.3V, GND, and Vin","only 12V","USB and HDMI"]', '5V, 3.3V, GND, and Vin'),
    (11, 'The UNO has a built-in LED wired to digital pin', '["13","7","0"]', '13'),
    (12, 'Some digital pins marked with a ~ can also produce', '["PWM output","analog input","Wi-Fi"]', 'PWM output'),
    (13, 'Which board is the standard beginner board used in this course?', '["Arduino UNO","Arduino Mega","Pandaboard"]', 'Arduino UNO'),
    (14, 'Which Arduino board has the most digital pins (54) for larger projects?', '["Arduino Mega","Arduino Nano","Arduino Leonardo"]', 'Arduino Mega'),
    (15, 'Which Arduino board is tiny and breadboard-friendly?', '["Arduino Nano","Arduino Mega","Arduino Due"]', 'Arduino Nano'),
    (16, 'In the bare minimum sketch, setup() runs', '["once at power-on or reset","continuously","only when unplugged"]', 'once at power-on or reset'),
    (17, 'In the bare minimum sketch, loop() runs', '["over and over forever","only once","never"]', 'over and over forever'),
    (18, 'setup() is used to initialize', '["variables and pin modes","serial printing only","libraries only"]', 'variables and pin modes'),
    (19, 'A breadboard is used to', '["build temporary circuits without soldering","store uploaded programs","measure resistance"]', 'build temporary circuits without soldering'),
    (20, 'The longer leg of an LED is the', '["anode (+)","cathode (−)","gate"]', 'anode (+)'),
    (21, 'A pushbutton on a digital pin acts as a', '["digital input","actuator","display"]', 'digital input'),
    (22, 'A potentiometer is read by the Arduino as an', '["analog value","digital pulse","serial packet"]', 'analog value'),
    (23, 'The TMP36 temperature sensor outputs a voltage', '["proportional to temperature","that is always 5V","proportional to light"]', 'proportional to temperature'),
    (24, 'A servo motor is an example of a', '["sensor","actuator","resistor"]', 'actuator')
  ) AS q(pos, question, options, correct_answer);

  ------------------------------------------------------------------ Quiz: Lab 1
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz — Lab Activity 1 (Blinking LED)' AND deleted_at IS NULL;
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz — Lab Activity 1 (Blinking LED)', 10, true, 0, 'highest_score', 20,
          NULL, now() + interval '14 days')
  RETURNING id INTO v_quiz;
  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'Laboratory Activity 1 builds a blinking LED using which board?', '["Arduino UNO","Raspberry Pi","Mbed"]', 'Arduino UNO'),
    (2,  'The lab connects the LED in series with a', '["1 kΩ resistor","10 kΩ potentiometer","capacitor"]', '1 kΩ resistor'),
    (3,  'The color code for the lab''s 1 kΩ resistor is', '["brown-black-red","red-red-brown","yellow-violet-red"]', 'brown-black-red'),
    (4,  'How many male-to-male jumper wires does the lab require?', '["2","4","1"]', '2'),
    (5,  'How many LEDs does the circuit use?', '["1","2","3"]', '1'),
    (6,  'One jumper wire carries the signal from a digital pin; the other connects to', '["GND","5V","3.3V"]', 'GND'),
    (7,  'The LED and the resistor are connected', '["in series","in parallel","back-to-back"]', 'in series'),
    (8,  'The purpose of the current-limiting resistor is to', '["protect the LED from excessive current","make the LED blink faster","store charge"]', 'protect the LED from excessive current'),
    (9,  'Connecting an LED directly to 5 V without a resistor will', '["likely burn out the LED","do nothing","dim the LED forever"]', 'likely burn out the LED'),
    (10, 'The longer LED leg (anode) connects toward the', '["resistor/pin side","ground side","either side"]', 'resistor/pin side'),
    (11, 'The Blink example sketch lives under File → Examples →', '["01.Basics","03.Analog","05.Characters"]', '01.Basics'),
    (12, 'Before uploading, the IDE board setting must be', '["Arduino Uno","Arduino Mega","Generic AVR"]', 'Arduino Uno'),
    (13, 'The correct board port is selected under Tools →', '["Port","Monitor","Library"]', 'Port'),
    (14, 'The Upload button in the IDE is the', '["right-arrow (→) button","left-arrow button","checkmark only"]', 'right-arrow (→) button'),
    (15, 'In the stock Blink sketch, the LED stays ON for', '["1000 ms (1 second)","250 ms","5000 ms"]', '1000 ms (1 second)'),
    (16, 'A full blink cycle (ON + OFF) in the stock sketch takes', '["2 seconds","1 second","4 seconds"]', '2 seconds'),
    (17, 'Changing both delays to delay(250) makes the LED blink', '["4 times faster","slower","the same"]', '4 times faster'),
    (18, 'digitalWrite(pin, HIGH) on the LED pin makes the LED', '["turn ON","turn OFF","blink twice"]', 'turn ON'),
    (19, 'If the LED never lights, which is a possible cause?', '["LED legs reversed in the breadboard","delay is 1000 ms","the board was uploaded successfully"]', 'LED legs reversed in the breadboard'),
    (20, 'The circuit ground wire must connect from the breadboard to any', '["GND pin on the Arduino","analog pin","USB pin"]', 'GND pin on the Arduino'),
    (21, 'Which function in the Blink sketch turns the LED on and off repeatedly?', '["loop()","setup()","main()"]', 'loop()'),
    (22, 'The delay() function is used to', '["pause the program for a given time","read a sensor","upload a sketch"]', 'pause the program for a given time'),
    (23, 'One learning outcome of the lab is to troubleshoot common', '["wiring or connection errors","IDE downloads","Windows updates"]', 'wiring or connection errors'),
    (24, 'Before touching the breadboard, the lab procedure says to', '["disconnect the Arduino from power/USB","hold the LED by its legs","turn the potentiometer"]', 'disconnect the Arduino from power/USB')
  ) AS q(pos, question, options, correct_answer);
END $$;
