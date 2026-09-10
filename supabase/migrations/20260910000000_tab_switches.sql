-- Add tab_switches column to quiz_attempts for anti-cheat logging.
-- Stores an array of { at: number, type: "blur" | "visibilitychange" } objects.
ALTER TABLE public.quiz_attempts
  ADD COLUMN IF NOT EXISTS tab_switches jsonb NOT NULL DEFAULT '[]'::jsonb;
