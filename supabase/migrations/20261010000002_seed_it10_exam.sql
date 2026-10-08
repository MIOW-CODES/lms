-- 1st Quarter Exam (IT 10) — 65-question bank, 50 drawn per attempt.
-- Source: "1st Quarter Exam.docx" + TOS request (20 identification Arduino/SIK,
-- 10 resistance value, 10 color code). question_count=50 makes getQuizPublic
-- draw a fresh random subset per attempt (unseen-first), so no two students —
-- and no retake — see the same set. Re-runnable: retires prior copies first.
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
    RAISE EXCEPTION 'IT 10 course not found — create the course before seeding the exam';
  END IF;

  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = '1st Quarter Exam' AND deleted_at IS NULL;

  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES
    (v_course, '1st Quarter Exam', 45, true, 0, 'highest_score', 50,
     NULL, now() + interval '14 days')
  RETURNING id INTO v_quiz;

  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    -- ===== A. Multiple choice (verbatim from the docx) — 15 =====
    (1,  'Which one is the fastest Led blinking?', '["delay(500);","delay(1000);","delay(1500);"]', 'delay(500);'),
    (2,  'Which one of the following is a user defined function?', '["loop();","calculate();","setup();"]', 'calculate();'),
    (3,  'Which function runs only one time?', '["loop();","calculate();","setup();"]', 'setup();'),
    (4,  'To pause a system for 2 seconds in Arduino, we use which line of code?', '["delay(20);","delay(200);","delay(2000);"]', 'delay(2000);'),
    (5,  'How many analog pins are on an Arduino board?', '["5","6","7"]', '6'),
    (6,  'How many digital pins are on an Arduino board?', '["10","12","14"]', '14'),
    (7,  'All of these are input devices EXCEPT', '["Temp Sensor","LED","Ultrasonic Sensor"]', 'LED'),
    (8,  'What is the result of the following code: print(7%3);', '["0","1","2"]', '1'),
    (9,  'The following line of code means pinMode(12, OUTPUT);', '["Set the device in pin 12 as output.","Set the device in pin 12 as input.","Set the device in pin 12 set to Off state."]', 'Set the device in pin 12 as output.'),
    (10, 'To control the current through a circuit we use', '["Wire","Sensor","Resistor"]', 'Resistor'),
    (11, 'Code writing and uploading into the Arduino board is done using which tool?', '["IDE","PC","SOME"]', 'IDE'),
    (12, 'The Arduino board is also called a', '["Timer","Oscillator","Microcontroller"]', 'Microcontroller'),
    (13, 'To ground the circuit, which pin is used in Arduino?', '["RESET","GND","PIN"]', 'GND'),
    (14, 'Arduino IDE consists of 2 functions. What are they?', '["build() & loop()","setup() & build()","setup() & loop()"]', 'setup() & loop()'),
    (15, 'digitalWrite(13, LOW); turns the LED on pin 13', '["ON","OFF","DIM"]', 'OFF'),
    -- ===== B. Resistor color code (from the docx) — 10 =====
    (16, 'Decode the value: Brown, Black, Red, Gold.', '["1 kΩ ±5%","100 Ω ±5%","10 kΩ ±5%"]', '1 kΩ ±5%'),
    (17, 'Decode the value: Yellow, Violet, Yellow, Gold.', '["470 kΩ ±5%","47 kΩ ±5%","4.7 MΩ ±5%"]', '470 kΩ ±5%'),
    (18, 'Decode the value: Brown, Black, Green, Gold.', '["1 MΩ ±5%","100 kΩ ±5%","10 MΩ ±5%"]', '1 MΩ ±5%'),
    (19, 'Decode the value: Blue, Grey, Black, Gold.', '["68 Ω ±5%","680 Ω ±5%","6.8 kΩ ±5%"]', '68 Ω ±5%'),
    (20, 'Decode the value: Orange, White, Orange, Gold.', '["39 kΩ ±5%","390 kΩ ±5%","3.9 kΩ ±5%"]', '39 kΩ ±5%'),
    (21, 'Decode the value: Grey, Red, Gold, Gold.', '["8.2 Ω ±5%","82 Ω ±5%","820 Ω ±5%"]', '8.2 Ω ±5%'),
    (22, 'Decode the value: Yellow, Violet, Green, Silver.', '["4.7 MΩ ±10%","47 MΩ ±10%","4.7 kΩ ±10%"]', '4.7 MΩ ±10%'),
    (23, 'Decode the value: Yellow, Violet, Black, Gold.', '["47 Ω ±5%","470 Ω ±5%","4.7 kΩ ±5%"]', '47 Ω ±5%'),
    (24, 'Decode the value: Orange, Black, Red, Silver.', '["3 kΩ ±10%","30 kΩ ±10%","300 Ω ±10%"]', '3 kΩ ±10%'),
    (25, 'Decode the value: Green, Blue, Yellow, Silver.', '["560 kΩ ±10%","56 kΩ ±10%","5.6 MΩ ±10%"]', '560 kΩ ±10%'),
    -- ===== C. Finding resistance value (Ohm''s law) — 10 =====
    (26, 'A 12 V source pushes 60 mA through a resistor. What is its resistance?', '["200 Ω","2 kΩ","20 Ω"]', '200 Ω'),
    (27, 'What resistance draws 10 mA from a 5 V source?', '["500 Ω","5 kΩ","50 Ω"]', '500 Ω'),
    (28, 'What resistance draws 33 mA from a 3.3 V source?', '["10 Ω","100 Ω","1 kΩ"]', '100 Ω'),
    (29, 'What resistance draws 80 mA from a 24 V source?', '["30 Ω","300 Ω","3 kΩ"]', '300 Ω'),
    (30, 'What resistance draws 30 mA from a 1.5 V source?', '["5 Ω","50 Ω","500 Ω"]', '50 Ω'),
    (31, 'What resistance draws 40 mA from a 6 V source?', '["15 Ω","150 Ω","1.5 kΩ"]', '150 Ω'),
    (32, 'What resistance draws 55 mA from a 110 V source?', '["200 Ω","2 kΩ","20 kΩ"]', '2 kΩ'),
    (33, 'What resistance draws 2 mA from a 3 V source?', '["150 Ω","1.5 kΩ","15 kΩ"]', '1.5 kΩ'),
    (34, 'What resistance draws 50 mA from a 20 V source?', '["40 Ω","400 Ω","4 kΩ"]', '400 Ω'),
    (35, 'What resistance draws 64 mA from a 16 V source?', '["25 Ω","250 Ω","2.5 kΩ"]', '250 Ω'),
    -- ===== D. Identification (Arduino family + SIK components) — 20 =====
    (36, 'It is an open-source electronics platform based on easy-to-use hardware and software.', '[]', 'arduino'),
    (37, 'The tiny computer on the Arduino board is called a ______.', '[]', 'microcontroller'),
    (38, 'A solderless board used to build temporary prototypes without soldering.', '[]', 'breadboard'),
    (39, 'Wires with a pin on both ends used to connect components on a breadboard.', '[]', 'jumper wires||jumper wire||jumper'),
    (40, 'A three-terminal resistor with a rotating shaft used to adjust resistance.', '[]', 'potentiometer||trimmer||trimpot'),
    (41, 'This component allows electricity to flow in only one direction.', '[]', 'diode||signal diode||rectifier diode'),
    (42, 'The LED''s longer leg is called the ______.', '[]', 'anode'),
    (43, 'The LED''s shorter leg is called the ______.', '[]', 'cathode'),
    (44, 'How many ohms is a 10 kΩ resistor? Write digits only.', '[]', '10000||10,000'),
    (45, 'The instrument used to measure electrical resistance is called a ______.', '[]', 'multimeter||ohmmeter||multi meter'),
    (46, 'Color code: a resistor with bands Red-Red-Brown-Gold is how many ohms? (digits only)', '[]', '220'),
    (47, 'The SIK sensor that measures nearby object distance using sound waves is the ______ sensor.', '[]', 'ultrasonic||sonar'),
    (48, 'The SIK temperature sensor (TMP36) outputs a voltage proportional to ______.', '[]', 'temperature||heat'),
    (49, 'A light-dependent resistor changes its resistance based on ______.', '[]', 'light||brightness||light intensity'),
    (50, 'This SIK component converts electrical energy into continuous mechanical motion.', '[]', 'motor||dc motor||direct current motor'),
    (51, 'A programmable light that can glow in many colors using three channels is called a ______ LED.', '[]', 'rgb'),
    (52, 'The pin used to reset the Arduino board is the ______ pin.', '[]', 'reset'),
    (53, 'The pin that provides 0 volts reference is the ______ pin.', '[]', 'gnd||ground'),
    (54, 'The pin that provides regulated +5V on an Arduino Uno is the ______ pin.', '[]', '5v||5v power||power'),
    (55, 'A semiconductor component that amplifies or switches electronic signals is a ______.', '[]', 'transistor'),
    -- ===== E. Extra Arduino concepts (bank depth) — 10 =====
    (56, 'Arduino Uno digital pin 13 has a built-in ______.', '["LED","button","motor"]', 'LED'),
    (57, 'Which of these is a function used to send text over the serial port?', '["Serial.print()","delay()","pinMode()"]', 'Serial.print()'),
    (58, 'analogRead() returns values in which range?', '["0 to 1023","0 to 255","0 to 5"]', '0 to 1023'),
    (59, 'digitalWrite() can set a digital pin to', '["HIGH or LOW","0 to 1023","positive or negative"]', 'HIGH or LOW'),
    (60, 'A baud rate commonly used with Serial.begin() is', '["9600","1200","96000"]', '9600'),
    (61, 'The loop() function in Arduino', '["runs repeatedly","runs once","never runs"]', 'runs repeatedly'),
    (62, 'With pinMode(pin, INPUT_PULLUP), a pushbutton reads ______ when pressed.', '["LOW","HIGH","5 volts"]', 'LOW'),
    (63, 'Which unit measures electrical resistance?', '["ohm","volt","ampere"]', 'ohm'),
    (64, 'The Arduino Uno receives power over USB at approximately how many volts?', '["5","12","9"]', '5'),
    (65, 'Which Arduino function configures a pin as an output?', '["pinMode()","analogRead()","map()"]', 'pinMode()')
  ) AS q(pos, question, options, correct_answer);
END $$;
