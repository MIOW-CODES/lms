-- 20261012000020_require_breadboarding_in_sim_questions.sql
-- Every simulation (lab_task) quiz question must have a breadboarding task:
-- the Virtual Arduino Lab renders an empty board with manual pin-to-pin wiring,
-- so question text must explicitly require breadboard wiring.
--
-- 1) Backfill: lab_task = true rows whose question text lacks any wiring
--    reference get one appended sentence. Rubrics (correct_answer) are never
--    modified and no circuit specs are invented — only the generic wiring
--    requirement is added.
-- 2) Guard: a BEFORE trigger rejects future inserts/updates that would produce
--    a lab_task question without a wiring reference (mirrors the app-side Zod
--    rule in src/lib/server/schemas.server.ts).
--
-- Idempotent: the backfill only touches rows still missing wiring references
-- and the trigger is dropped/recreated, so this file is safe to re-run.

-- 1) Backfill existing rows --------------------------------------------
DO $$
DECLARE
  v_total   int;
  v_missing int;
  v_updated int;
BEGIN
  SELECT count(*) INTO v_total FROM public.quiz_questions WHERE lab_task;
  SELECT count(*) INTO v_missing
    FROM public.quiz_questions
   WHERE lab_task
     AND question !~* '(breadboard|wiring|wire|jumper|resistor|pin-to-pin)';

  UPDATE public.quiz_questions
     SET question = rtrim(question) || ' Complete the circuit wiring on the breadboard before running the sketch.'
   WHERE lab_task
     AND question !~* '(breadboard|wiring|wire|jumper|resistor|pin-to-pin)';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  RAISE NOTICE
    'require_breadboarding_in_sim_questions: % lab_task question(s) total, % lacked wiring references, % updated with a breadboard wiring requirement',
    v_total, v_missing, v_updated;
END $$;

-- 2) Guard future writes ------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_breadboarding_in_sim_questions()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.lab_task
     AND NEW.question !~* '(breadboard|wiring|wire|jumper|resistor|pin-to-pin)' THEN
    RAISE EXCEPTION
      'quiz_questions: lab_task questions must include a breadboard wiring task in the question text (mention a breadboard, wire/wiring, jumper, resistor, or pin-to-pin connection)'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_require_breadboarding_in_sim_questions ON public.quiz_questions;
CREATE TRIGGER trg_require_breadboarding_in_sim_questions
  BEFORE INSERT OR UPDATE OF question, lab_task ON public.quiz_questions
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_breadboarding_in_sim_questions();
