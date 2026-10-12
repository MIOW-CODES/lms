-- Defer the student PIN-change gate until after the 8 AM exam.
--
-- 20261013000050_pin_security.sql sets pin_must_change = true for all students
-- (approved policy: PIN = student ID is peer-login risk during graded work).
-- Enforcing it at first login means ~46 ICT1 students hit a PIN-change gate at
-- 8 AM exam start — friction and chaos risk on exam morning.
--
-- Decision (user-acknowledged, no objection): the admin PIN rotation from
-- 000050 still applies, but the student gate stays OFF through the exam.
-- Re-enable post-exam with a follow-up migration setting pin_must_change=true
-- for student-role profiles (or via admin Reset PIN flows).
--
-- Idempotent: only touches rows where the flag is currently true.
DO $$
DECLARE
  v_n int;
BEGIN
  UPDATE public.profiles
     SET pin_must_change = false
   WHERE role = 'student'
     AND pin_must_change IS TRUE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'defer_student_pin_gate: cleared pin_must_change on % student profile(s)', v_n;
END $$;
