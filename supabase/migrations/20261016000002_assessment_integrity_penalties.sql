-- Store the pre-penalty score and applied integrity deduction for auditability.
ALTER TABLE public.quiz_attempts
  ADD COLUMN IF NOT EXISTS raw_score integer,
  ADD COLUMN IF NOT EXISTS integrity_penalty integer NOT NULL DEFAULT 0;

UPDATE public.quiz_attempts
   SET raw_score = score
 WHERE raw_score IS NULL;

ALTER TABLE public.quiz_attempts
  ALTER COLUMN raw_score SET NOT NULL;

