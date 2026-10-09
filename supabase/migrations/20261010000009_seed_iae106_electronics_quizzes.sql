-- MIOW-LMS: Seed IAE 106 (Fundamentals of Electronics Technology) + Quizzes 1, 2, 3
--
-- Course: Fundamentals of Electronics Technology (IAE 106)
-- Target: College 2nd Year BTLED
-- Schedule:
--   - Friday 3:00-5:00 PM Lecture
--   - Monday 3:00-6:00 PM Lab 1
--   - Wednesday 3:00-6:00 PM Lab 2
--
-- Quizzes:
--   - Quiz 1: Resistor Reading (Color codes, digits, multiplier, tolerance, calculations)
--   - Quiz 2: Resistor connected in series, parallel and series parallel (Formulas, KVL, current/voltage divider)
--   - Quiz 3: Multi tester reading (VOM scales, zero ohm adjustment, ranges, safety)

DO $$
DECLARE
  v_teacher uuid;
  v_course uuid;
  v_quiz1 uuid;
  v_quiz2 uuid;
  v_quiz3 uuid;
BEGIN
  -- 1. Locate teacher
  SELECT id INTO v_teacher FROM public.profiles
   WHERE role IN ('teacher', 'admin')
   ORDER BY (role = 'teacher') DESC, created_at
   LIMIT 1;

  IF v_teacher IS NULL THEN
    v_teacher := 'b0000000-0000-4000-8000-000000000003'::uuid;
  END IF;

  -- 2. Insert or update course IAE 106
  INSERT INTO public.courses (
    id, title, code, grade_level, education_level, college_year,
    program, color, grading_system, teacher_id, days_of_week, start_time, end_time
  )
  VALUES (
    'e1060000-0000-4000-8000-000000000106'::uuid,
    'Fundamentals of Electronics Technology',
    'IAE 106',
    14,
    'college',
    2,
    'BTLED',
    'amber',
    'college_semestral',
    v_teacher,
    ARRAY['fri']::text[],
    '15:00:00'::time,
    '17:00:00'::time
  )
  ON CONFLICT (code) DO UPDATE SET
    title = EXCLUDED.title,
    grade_level = EXCLUDED.grade_level,
    education_level = EXCLUDED.education_level,
    college_year = EXCLUDED.college_year,
    program = EXCLUDED.program,
    grading_system = EXCLUDED.grading_system,
    teacher_id = EXCLUDED.teacher_id,
    days_of_week = EXCLUDED.days_of_week,
    start_time = EXCLUDED.start_time,
    end_time = EXCLUDED.end_time
  RETURNING id INTO v_course;

  IF v_course IS NULL THEN
    SELECT id INTO v_course FROM public.courses WHERE code = 'IAE 106';
  END IF;

  -- 3. Meetings: Friday Lecture (3-5 PM), Monday Lab 1 (3-6 PM), Wednesday Lab 2 (3-6 PM)
  INSERT INTO public.course_meetings
    (course_id, kind, label, days_of_week, start_time, end_time, sort_order)
  SELECT
    v_course, v.kind, v.label, v.days::text[], v.st::time, v.et::time, v.ord
  FROM (VALUES
    ('lecture', 'Lecture', '{fri}', '15:00:00', '17:00:00', 0),
    ('lab',     'Lab 1',   '{mon}', '15:00:00', '18:00:00', 1),
    ('lab',     'Lab 2',   '{wed}', '15:00:00', '18:00:00', 2)
  ) AS v(kind, label, days, st, et, ord)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.course_meetings m
    WHERE m.course_id = v_course AND m.label = v.label
  );

  ------------------------------------------------------------------ Quiz 1: Resistor Reading
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz 1: Resistor Reading' AND deleted_at IS NULL;

  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz 1: Resistor Reading', 25, true, 0, 'highest_score', 20,
          now(), now() + interval '30 days')
  RETURNING id INTO v_quiz1;

  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz1, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'What does the color code system on axial lead resistors primarily indicate?', '["Resistance value and tolerance","Maximum voltage limit","Temperature coefficient only","Inductance rating"]', 'Resistance value and tolerance'),
    (2,  'In the standard resistor color code chart, what numerical value corresponds to Black?', '["0","1","2","5"]', '0'),
    (3,  'What numerical value does the color Brown represent in the resistor color code?', '["1","0","2","3"]', '1'),
    (4,  'Which color represents the number 2 in the resistor color code?', '["Red","Orange","Brown","Yellow"]', 'Red'),
    (5,  'Which color represents the number 4 in the resistor color code?', '["Yellow","Orange","Green","Violet"]', 'Yellow'),
    (6,  'Which color represents the number 7 in the resistor color code?', '["Violet","Blue","Gray","White"]', 'Violet'),
    (7,  'On a standard 4-band resistor, which band represents the decimal multiplier?', '["Third band","First band","Second band","Fourth band"]', 'Third band'),
    (8,  'On a standard 4-band resistor, what does the fourth band indicate?', '["Tolerance rating (± percentage)","Power rating in Watts","Third significant digit","Voltage drop"]', 'Tolerance rating (± percentage)'),
    (9,  'What tolerance percentage is indicated by a Gold band in the 4th position?', '["±5%","±10%","±1%","±20%"]', '±5%'),
    (10, 'What tolerance percentage is indicated by a Silver band in the 4th position?', '["±10%","±5%","±2%","±20%"]', '±10%'),
    (11, 'A 4-band resistor has color bands Brown, Black, Red, Gold. What is its nominal resistance?', '["1,000 Ω (1 kΩ)","100 Ω","10,000 Ω (10 kΩ)","120 Ω"]', '1,000 Ω (1 kΩ)'),
    (12, 'A 4-band resistor has color bands Yellow, Violet, Orange, Gold. What is its nominal resistance?', '["47,000 Ω (47 kΩ)","4,700 Ω (4.7 kΩ)","470,000 Ω (470 kΩ)","37,000 Ω (37 kΩ)"]', '47,000 Ω (47 kΩ)'),
    (13, 'A 4-band resistor has color bands Red, Red, Brown, Gold. What is its resistance value?', '["220 Ω","2.2 kΩ","22 Ω","220 kΩ"]', '220 Ω'),
    (14, 'A 4-band resistor has color bands Brown, Black, Orange, Silver. What is its value and tolerance?', '["10 kΩ ± 10%","1 kΩ ± 5%","100 kΩ ± 10%","10 kΩ ± 5%"]', '10 kΩ ± 10%'),
    (15, 'A 4-band resistor has color bands Orange, White, Green, Gold. What is its resistance value?', '["3.9 MΩ (3,900,000 Ω)","390 kΩ","39 kΩ","3.9 kΩ"]', '3.9 MΩ (3,900,000 Ω)'),
    (16, 'What color bands represent a 330 Ω resistor with ±5% tolerance on a 4-band resistor?', '["Orange, Orange, Brown, Gold","Orange, Orange, Red, Gold","Brown, Black, Brown, Gold","Yellow, Violet, Brown, Gold"]', 'Orange, Orange, Brown, Gold'),
    (17, 'In a 5-band precision resistor, what do the first three bands represent?', '["The first three significant digits","Two significant digits and a multiplier","Tolerance and two digits","Power rating and two digits"]', 'The first three significant digits'),
    (18, 'A 5-band resistor has bands: Brown, Black, Black, Brown, Brown. What is its resistance and tolerance?', '["1,000 Ω (1 kΩ) ± 1%","100 Ω ± 5%","10 kΩ ± 1%","100 Ω ± 2%"]', '1,000 Ω (1 kΩ) ± 1%'),
    (19, 'If a 1 kΩ resistor has a ±5% tolerance (Gold), what is the acceptable measured resistance range?', '["950 Ω to 1,050 Ω","900 Ω to 1,100 Ω","980 Ω to 1,020 Ω","990 Ω to 1,010 Ω"]', '950 Ω to 1,050 Ω'),
    (20, 'When Gold is used as the 3rd band (multiplier) on a 4-band resistor, what multiplier factor does it represent?', '["0.1","0.01","10","100"]', '0.1')
  ) AS q(pos, question, options, correct_answer);

  ------------------------------------------------------------------ Quiz 2: Resistor connected in series, parallel and series parallel
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz 2: Resistor connected in series, parallel and series parallel' AND deleted_at IS NULL;

  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz 2: Resistor connected in series, parallel and series parallel', 30, true, 0, 'highest_score', 20,
          now(), now() + interval '30 days')
  RETURNING id INTO v_quiz2;

  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz2, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'How is the total equivalent resistance (RT) calculated in a series circuit?', '["RT = R1 + R2 + ... + Rn","1/RT = 1/R1 + 1/R2 + ...","RT = (R1 * R2) / (R1 + R2)","RT = R1 * R2 * ... * Rn"]', 'RT = R1 + R2 + ... + Rn'),
    (2,  'What electrical quantity remains constant and identical through all components in a series circuit?', '["Current (I)","Voltage (V)","Power (P)","Resistance (R)"]', 'Current (I)'),
    (3,  'Three resistors of values 100 Ω, 220 Ω, and 470 Ω are connected in series. What is the total equivalent resistance?', '["790 Ω","690 Ω","590 Ω","890 Ω"]', '790 Ω'),
    (4,  'If two 1 kΩ resistors are connected in series across a 10 V DC supply, what is the total current flowing in the circuit?', '["5 mA","10 mA","20 mA","2.5 mA"]', '5 mA'),
    (5,  'According to Kirchhoff''s Voltage Law (KVL), what is the sum of all voltage drops in a closed series loop?', '["Equal to the total source voltage applied","Always zero including the source","Greater than the source voltage","Equal to the smallest resistor voltage drop"]', 'Equal to the total source voltage applied'),
    (6,  'What is the formula for the total equivalent resistance (RT) of two parallel resistors R1 and R2?', '["RT = (R1 * R2) / (R1 + R2)","RT = R1 + R2","RT = (R1 + R2) / (R1 * R2)","RT = R1 * R2"]', 'RT = (R1 * R2) / (R1 + R2)'),
    (7,  'What electrical quantity is identical across every branch of a parallel circuit?', '["Voltage (V)","Current (I)","Power (P)","Conductance (G)"]', 'Voltage (V)'),
    (8,  'Two 100 Ω resistors are connected in parallel. What is their equivalent resistance?', '["50 Ω","200 Ω","25 Ω","100 Ω"]', '50 Ω'),
    (9,  'In any parallel resistive circuit, the total equivalent resistance (RT) is always:', '["Less than the smallest individual branch resistance","Greater than the largest branch resistance","Equal to the sum of all branch resistances","Equal to the average of branch resistances"]', 'Less than the smallest individual branch resistance'),
    (10, 'Three identical 300 Ω resistors are connected in parallel. What is the total equivalent resistance?', '["100 Ω","900 Ω","150 Ω","300 Ω"]', '100 Ω'),
    (11, 'A 12 V source is connected across two parallel resistors: R1 = 6 Ω and R2 = 12 Ω. What is the current through R1?', '["2 A","1 A","3 A","0.5 A"]', '2 A'),
    (12, 'For a parallel circuit with 12 V across R1 = 6 Ω and R2 = 12 Ω, what is the total current (IT) supplied by the source?', '["3 A","1 A","2 A","4 A"]', '3 A'),
    (13, 'If one resistor in a parallel branch burns out into an open circuit, what happens to the remaining branches?', '["They continue to operate with the same voltage applied","Current stops flowing through all other branches","Voltage across the other branches drops to zero","Total circuit resistance drops to zero"]', 'They continue to operate with the same voltage applied'),
    (14, 'If one resistor in a series circuit becomes an open circuit, what happens to the current in the circuit?', '["Current drops to zero throughout the entire circuit (I = 0)","Current doubles in the remaining components","Voltage across all other resistors increases","The remaining resistors continue to operate normally"]', 'Current drops to zero throughout the entire circuit (I = 0)'),
    (15, 'In a voltage divider circuit with series resistors R1 and R2 across Vin, what is the voltage across R2?', '["V2 = Vin * [R2 / (R1 + R2)]","V2 = Vin * [R1 / (R1 + R2)]","V2 = Vin * [(R1 + R2) / R2]","V2 = Vin / (R1 + R2)"]', 'V2 = Vin * [R2 / (R1 + R2)]'),
    (16, 'How should you begin analyzing a series-parallel combination circuit to find equivalent resistance?', '["Simplify purely series or parallel sub-groups first, working back toward the source","Add all resistors together as a single series string","Divide the supply voltage by the total number of components","Calculate power dissipation before finding resistance"]', 'Simplify purely series or parallel sub-groups first, working back toward the source'),
    (17, 'A circuit has R1 = 100 Ω in series with a parallel pair R2 = 200 Ω and R3 = 200 Ω. What is the total equivalent resistance?', '["200 Ω","300 Ω","500 Ω","100 Ω"]', '200 Ω'),
    (18, 'In the circuit (R1 = 100 Ω in series with 200 Ω || 200 Ω, RT = 200 Ω), with a 20 V supply, what is the total source current?', '["100 mA (0.1 A)","200 mA (0.2 A)","50 mA (0.05 A)","10 mA (0.01 A)"]', '100 mA (0.1 A)'),
    (19, 'Two parallel resistors of 30 Ω and 60 Ω are connected in series with a 10 Ω resistor. What is the total equivalent resistance?', '["30 Ω","100 Ω","20 Ω","40 Ω"]', '30 Ω'),
    (20, 'In a parallel circuit, which branch carries the greater amount of current?', '["The branch with the lower resistance value","The branch with the higher resistance value","Both branches carry identical current regardless of resistance","Current only flows in the branch closest to the positive terminal"]', 'The branch with the lower resistance value')
  ) AS q(pos, question, options, correct_answer);

  ------------------------------------------------------------------ Quiz 3: Multi tester reading
  UPDATE public.quizzes SET deleted_at = now()
   WHERE course_id = v_course AND title = 'Quiz 3: Multi tester reading' AND deleted_at IS NULL;

  INSERT INTO public.quizzes
    (course_id, title, duration_minutes, allow_retake, max_attempts,
     retake_score_policy, question_count, opens_at, closes_at)
  VALUES (v_course, 'Quiz 3: Multi tester reading', 25, true, 0, 'highest_score', 20,
          now(), now() + interval '30 days')
  RETURNING id INTO v_quiz3;

  INSERT INTO public.quiz_questions (quiz_id, question, options, correct_answer, position)
  SELECT v_quiz3, q.question, q.options::jsonb, q.correct_answer, q.pos
  FROM (VALUES
    (1,  'What does the acronym VOM stand for in electrical and electronics testing?', '["Volt-Ohm-Milliammeter","Voltage Output Monitor","Variable Oscillator Meter","Vector Ohmic Multiplier"]', 'Volt-Ohm-Milliammeter'),
    (2,  'Why is the resistance (Ohms, Ω) scale on an analog multimeter unique compared to voltage and current scales?', '["It is non-linear and reads from right (0) to left (∞)","It is linear and reads left (0) to right (max)","It reads from center zero outward","It displays values in decibels only"]', 'It is non-linear and reads from right (0) to left (∞)'),
    (3,  'What critical calibration procedure must be performed whenever switching resistance ranges on an analog multimeter?', '["Zero Ohm Adjustment (shorting the test probes together and adjusting to 0 Ω)","Frequency tuning of the meter coil","AC line phase balance calibration","Swapping the probe polarities"]', 'Zero Ohm Adjustment (shorting the test probes together and adjusting to 0 Ω)'),
    (4,  'What safety precaution is mandatory before measuring the resistance of an in-circuit component?', '["Disconnect power from the circuit and discharge all capacitors","Turn on circuit power so the meter can sense current","Set the range to the highest AC voltage range","Ground both meter test probes together to earth"]', 'Disconnect power from the circuit and discharge all capacitors'),
    (5,  'If the selector switch is set to the R x 10 range and the pointer indicates 15 on the ohm scale, what is the measured resistance?', '["150 Ω","15 Ω","1,500 Ω","1.5 Ω"]', '150 Ω'),
    (6,  'If the selector switch is set to the R x 1k range and the pointer indicates 4.7, what is the measured resistance?', '["4.7 kΩ (4,700 Ω)","470 Ω","47 kΩ","0.47 kΩ"]', '4.7 kΩ (4,700 Ω)'),
    (7,  'If the analog meter pointer does not deflect from the far left (rests on ∞) during a resistance measurement, what does it indicate?', '["An open circuit (infinite resistance / broken path)","A short circuit (0 Ω)","A normal low-resistance wire","A fully charged battery"]', 'An open circuit (infinite resistance / broken path)'),
    (8,  'If the meter pointer deflects completely to the far right (resting on 0 Ω) during a continuity check, what does it signify?', '["Continuity exists / closed circuit with negligible resistance","The circuit is completely open","The component has blown open","The meter fuse has blown"]', 'Continuity exists / closed circuit with negligible resistance'),
    (9,  'When measuring an unknown DC voltage with a multimeter, what range should the selector switch initially be set to?', '["The highest voltage range to prevent meter needle damage/overload","The lowest voltage range for maximum sensitivity","The resistance R x 1 range","The highest current range"]', 'The highest voltage range to prevent meter needle damage/overload'),
    (10, 'Which test lead is connected to the COM (common / reference / ground) terminal on a multimeter?', '["Black lead","Red lead","Yellow lead","Green lead"]', 'Black lead'),
    (11, 'When measuring DC voltage with an analog multitester, what happens if test probe polarities are accidentally reversed?', '["The pointer deflects backward (to the left of zero), risking needle damage","The meter displays a minus sign on the scale","The internal fuse blows immediately","The reading remains accurate and positive"]', 'The pointer deflects backward (to the left of zero), risking needle damage'),
    (12, 'How must a multitester be connected to measure electric current flowing in a circuit?', '["In series with the load by opening the circuit line","In parallel directly across the power supply terminals","Across the load resistor without breaking the circuit","Between circuit ground and the chassis"]', 'In series with the load by opening the circuit line'),
    (13, 'How must a multitester be connected to measure voltage across an active component?', '["In parallel across the component","In series by cutting the circuit trace","In series with the power supply negative terminal","Between the component and an isolated ground"]', 'In parallel across the component'),
    (14, 'What happens if a multitester set to current (ammeter) mode is mistakenly connected in parallel across a voltage source?', '["A heavy short-circuit current flows through the meter, blowing its fuse or damaging it","It accurately reads the circuit voltage","The pointer remains at zero safely","The voltage source automatically shuts down without issue"]', 'A heavy short-circuit current flows through the meter, blowing its fuse or damaging it'),
    (15, 'If the selector switch is on the DCV 50 V range and the pointer rests on 30 on the 0–50 scale, what is the measured voltage?', '["30 V","3 V","300 V","15 V"]', '30 V'),
    (16, 'If the selector switch is on the DCV 10 V range and the pointer indicates 15 on a 0–50 scale, what is the measured voltage?', '["3 V","15 V","1.5 V","0.3 V"]', '3 V'),
    (17, 'What provides the electrical power needed to measure resistance with an analog multimeter?', '["The meter''s internal battery (e.g. 1.5 V / 9 V)","The circuit under test must be powered","An external wall outlet adapter","Electromagnetic induction from test leads"]', 'The meter''s internal battery (e.g. 1.5 V / 9 V)'),
    (18, 'When an analog multimeter cannot be zeroed on the R x 1 range (pointer cannot reach 0 Ω), what is the most probable cause?', '["The internal battery is weak or depleted","The test leads are excessively long","The meter movement coil is burned out","The zero adjust knob is set to reverse polarity"]', 'The internal battery is weak or depleted'),
    (19, 'What setting should the multimeter selector switch be placed in when finished and storing the device?', '["OFF or highest AC Voltage range (e.g. ACV 1000V)","Resistance R x 1 range","Current DCA 250 mA range","Lowest DC Voltage range"]', 'OFF or highest AC Voltage range (e.g. ACV 1000V)'),
    (20, 'What is parallax error when reading an analog meter scale, and how is it eliminated?', '["An apparent shift in needle position when viewed at an angle; eliminated by lining up the needle with its mirror image","A calibration drift caused by ambient temperature changes; eliminated by cooling the meter","A friction error in the jeweled meter bearings; eliminated by tapping the meter case","A reading error caused by depleted batteries; eliminated by replacing batteries"]', 'An apparent shift in needle position when viewed at an angle; eliminated by lining up the needle with its mirror image')
  ) AS q(pos, question, options, correct_answer);

  -- 4. Auto-enroll eligible college students (all students in section B8 or BTLED or 2026-0000)
  INSERT INTO public.enrollments (student_id, course_id)
  SELECT p.id, v_course
  FROM public.profiles p
  WHERE p.role = 'student'
    AND p.deleted_at IS NULL
  ON CONFLICT (student_id, course_id) DO NOTHING;

END $$;
