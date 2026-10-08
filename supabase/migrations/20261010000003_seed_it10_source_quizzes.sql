-- Source-material quizzes for IT 10 — one per lecture file, authored from the
-- actual PDF content. Each: 24-item bank, question_count=20 (fresh unseen-first
-- draw per attempt), 10 minutes, unlimited retakes, 14-day window.
-- Re-runnable: retires prior copies of each quiz first (same pattern as the exam).
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

  ------------------------------------------------------------------ Quiz 1
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz — Arduino Part 2' AND deleted_at IS NULL;
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz — Arduino Part 2', 10, true, 0, 'highest_score', 20,
          NULL, now() + interval '14 days')
  RETURNING id INTO v_quiz;
  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'Arduino is an ______ electronic prototyping platform.', '["open-source","closed-source","commercial-only"]', 'open-source'),
    (2,  'In the bare minimum code, which function runs only once when the Arduino is powered on or reset?', '["setup()","loop()","main()"]', 'setup()'),
    (3,  'The setup() function is used to initialize', '["variables and pin modes","serial printing only","millis timers"]', 'variables and pin modes'),
    (4,  'The loop() function runs', '["continuously until power is off","only once","only when reset"]', 'continuously until power is off'),
    (5,  'In microcontroller programming, loop() is similar to which construct?', '["while (1)","if (1)","switch (1)"]', 'while (1)'),
    (6,  'The main logic of an Arduino sketch goes in the', '["loop()","setup()","libraries folder"]', 'loop()'),
    (7,  'Libraries are collections of code that make it easy to connect to a', '["sensor, display, or module","power supply only","USB cable"]', 'sensor, display, or module'),
    (8,  'Which built-in library makes it easy to talk to character LCD displays?', '["LiquidCrystal","Servo","EEPROM"]', 'LiquidCrystal'),
    (9,  'Hundreds of additional Arduino libraries are available', '["for download on the Internet","only on CD","inside the board"]', 'for download on the Internet'),
    (10, 'A sensor is a converter that measures a physical quantity and converts it to a', '["signal readable by an instrument or Arduino","mechanical motion","battery charge"]', 'signal readable by an instrument or Arduino'),
    (11, 'Which of these is a sensor?', '["Temperature sensor","Engine","Valve"]', 'Temperature sensor'),
    (12, 'An actuator converts energy into', '["motion","light","sound only"]', 'motion'),
    (13, 'Which of these is an actuator?', '["Pump","Potentiometer","Thermistor"]', 'Pump'),
    (14, 'Sensors and actuators can be either', '["digital or analog","USB or serial","5V or 3V only"]', 'digital or analog'),
    (15, 'Many sensors and actuators for Arduino come with', '["ready-made libraries","no documentation","custom PCBs only"]', 'ready-made libraries'),
    (16, 'A potentiometer is a simple knob that provides a variable', '["resistance","capacitance","voltage source"]', 'resistance'),
    (17, 'The Arduino reads a potentiometer as an', '["analog value","digital pulse","serial packet"]', 'analog value'),
    (18, 'Which of these is an example of a single-board device from the lecture?', '["Raspberry Pi","Hard disk","Monitor"]', 'Raspberry Pi'),
    (19, 'Mbed is an example of a', '["single-board device","resistor code","sensor library"]', 'single-board device'),
    (20, 'Early microcomputers typically consisted of circuit boards plugged into a', '["backplane","breadboard","USB hub"]', 'backplane'),
    (21, 'For the traffic light individual assessment, how many 220 Ω resistors are needed?', '["3","1","5"]', '3'),
    (22, 'The traffic light assessment builds with which board?', '["Arduino UNO","Raspberry Pi","Pandaboard"]', 'Arduino UNO'),
    (23, 'Which LEDs does the traffic light assessment require?', '["Red, Yellow, and Green","Red and Blue only","White and Green"]', 'Red, Yellow, and Green'),
    (24, 'The traffic light circuit is created in', '["Tinkercad","LibreOffice","the Serial Monitor"]', 'Tinkercad')
  ) AS q(pos, question, options, correct_answer);

  ------------------------------------------------------------------ Quiz 2
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz — Resistor Color Code' AND deleted_at IS NULL;
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz — Resistor Color Code', 10, true, 0, 'highest_score', 20,
          NULL, now() + interval '14 days')
  RETURNING id INTO v_quiz;
  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'On a 4-band resistor, the 1st band color gives the', '["1st number","tolerance","multiplier only"]', '1st number'),
    (2,  'On a 4-band resistor, the 2nd band color gives the', '["2nd number","# of zeros","tolerance"]', '2nd number'),
    (3,  'On a 4-band resistor, the 3rd band color gives the', '["# of zeros (multiplier)","1st number","tolerance"]', '# of zeros (multiplier)'),
    (4,  'On a 4-band resistor, the 4th band color gives the', '["tolerance (±)","3rd digit","voltage rating"]', 'tolerance (±)'),
    (5,  'To read a resistor, hold it with the gold or silver tolerance band to the', '["right","left","bottom"]', 'right'),
    (6,  'A gold tolerance band means ±', '["5%","10%","2%"]', '5%'),
    (7,  'A silver tolerance band means ±', '["10%","5%","1%"]', '10%'),
    (8,  'Red, Black, Yellow with silver tolerance (lecture example) equals', '["200,000 Ω ± 10%","20,000 Ω ± 10%","2,000 Ω ± 10%"]', '200,000 Ω ± 10%'),
    (9,  'Brown, Black, Red, Gold (Example 1) has a nominal value of', '["1,000 Ω","100 Ω","10,000 Ω"]', '1,000 Ω'),
    (10, 'The tolerance in Example 1 (gold band) is', '["±5%","±10%","±2%"]', '±5%'),
    (11, 'Yellow, Violet, Orange, Gold (Example 2) equals', '["47 kΩ ± 5%","470 kΩ ± 5%","4.7 kΩ ± 5%"]', '47 kΩ ± 5%'),
    (12, 'Orange, White, Green, Silver (Example 3) equals', '["3.9 MΩ ± 10%","390 kΩ ± 10%","3.9 kΩ ± 10%"]', '3.9 MΩ ± 10%'),
    (13, 'The tolerance in Example 3 (silver band) is', '["±10%","±5%","±1%"]', '±10%'),
    (14, 'Orange, Orange, Brown, Gold (lecture practice) equals', '["330 Ω ± 5%","33 Ω ± 5%","3.3 kΩ ± 5%"]', '330 Ω ± 5%'),
    (15, '5-band color codes are used for resistors with tolerances of', '["±1% or ±2%","±5% or ±10%","±20% or ±25%"]', '±1% or ±2%'),
    (16, 'In a 5-band code, the first three bands are', '["significant digits","multiplier and tolerance","all multipliers"]', 'significant digits'),
    (17, 'In a 5-band code, the 4th band is the', '["multiplier","tolerance","1st digit"]', 'multiplier'),
    (18, '5-band Brown, Black, Black, Red, Brown (Example 4) equals', '["1 kΩ ± 2%","100 Ω ± 2%","10 kΩ ± 2%"]', '1 kΩ ± 2%'),
    (19, '5-band Blue, Grey, Black, Orange, Brown (Example 5) equals', '["680 kΩ ± 1%","68 kΩ ± 1%","6.8 MΩ ± 1%"]', '680 kΩ ± 1%'),
    (20, 'Resistors are color coded for', '["easy reading","higher voltage","heat resistance"]', 'easy reading'),
    (21, 'To decode bands you match each color to its', '["color code chart","serial monitor","multimeter dial"]', 'color code chart'),
    (22, 'The color yellow represents which digit?', '["4","5","6"]', '4'),
    (23, 'The color violet represents which digit?', '["7","8","2"]', '7'),
    (24, 'A multimeter is used to check whether the color-coded value', '["matches the measured resistance","equals the voltage","matches the current"]', 'matches the measured resistance')
  ) AS q(pos, question, options, correct_answer);

  ------------------------------------------------------------------ Quiz 3
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz — Programming with Arduino' AND deleted_at IS NULL;
  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz — Programming with Arduino', 10, true, 0, 'highest_score', 20,
          NULL, now() + interval '14 days')
  RETURNING id INTO v_quiz;
  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'The guide is divided into 5 parts. Part 2 is', '["Basic Electronics","Introduction to Arduino","Arduino Examples"]', 'Basic Electronics'),
    (2,  'Which part of the guide covers the Arduino Development Environment?', '["Part 3","Part 1","Part 5"]', 'Part 3'),
    (3,  'Part 5 of the guide covers', '["Arduino Examples","Basic Electronics","the C++ language"]', 'Arduino Examples'),
    (4,  'In which part do you learn about LEDs and resistors?', '["Basic Electronics","Arduino Examples","Introduction"]', 'Basic Electronics'),
    (5,  'Connecting both terminals of a battery directly together is called a', '["short circuit","open loop","solder joint"]', 'short circuit'),
    (6,  'A breadboard is used to', '["wire circuits without soldering","store programs","measure resistance"]', 'wire circuits without soldering'),
    (7,  'The Arduino is connected to the PC for programming using a', '["USB cable","HDMI cable","ethernet cable"]', 'USB cable'),
    (8,  'The board''s restart (reset) button', '["restarts the program from setup()","clears the code","erases all libraries"]', 'restarts the program from setup()'),
    (9,  'In the IDE, the check/verify step', '["compiles the code and reports errors","uploads to the board","opens the Serial Monitor"]', 'compiles the code and reports errors'),
    (10, 'Uploading sends the compiled program to the board''s', '["microcontroller","hard drive","USB hub"]', 'microcontroller'),
    (11, 'The Serial Monitor is used to', '["view data sent from the board","draw circuits","install libraries"]', 'view data sent from the board'),
    (12, 'For Serial communication to work, the monitor''s baud rate must match the', '["baud rate in Serial.begin()","board voltage","pin number"]', 'baud rate in Serial.begin()'),
    (13, 'To turn an LED on with a digital pin you use', '["digitalWrite(pin, HIGH)","digitalRead(pin)","analogWrite(pin, 1023)"]', 'digitalWrite(pin, HIGH)'),
    (14, 'To read the state of a switch you use', '["digitalRead()","analogWrite()","tone()"]', 'digitalRead()'),
    (15, 'A potentiometer example reads its position with', '["analogRead()","digitalRead()","pulseIn()"]', 'analogRead()'),
    (16, 'analogRead() on an Arduino Uno returns values from', '["0 to 1023","0 to 255","0 to 5"]', '0 to 1023'),
    (17, 'analogWrite() on an Arduino Uno accepts values from', '["0 to 255","0 to 1023","0 to 100"]', '0 to 255'),
    (18, 'analogWrite() is used to produce', '["PWM output","serial data","analog input"]', 'PWM output'),
    (19, 'The temperature sensor example outputs a voltage', '["proportional to temperature","that is always 5V","proportional to current only"]', 'proportional to temperature'),
    (20, 'A light sensor (photoresistor/LDR) changes its resistance with', '["light level","temperature","humidity"]', 'light level'),
    (21, 'A thermistor is a resistor whose resistance depends on', '["temperature","light","magnetic fields"]', 'temperature'),
    (22, 'Which example from the guide blinks an LED using delay()?', '["Blinking LED","Thermistor","LCD display"]', 'Blinking LED'),
    (23, 'A variable of type float stores', '["decimal numbers","only whole numbers","text strings"]', 'decimal numbers'),
    (24, 'A variable of type int stores', '["whole numbers","decimal numbers","characters only"]', 'whole numbers')
  ) AS q(pos, question, options, correct_answer);
END $$;
