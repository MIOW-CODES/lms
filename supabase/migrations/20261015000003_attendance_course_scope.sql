-- Migration: Course-scope attendance logs
-- Allows attendance logs to reference the specific course matched at tap time.

ALTER TABLE public.attendance_logs
  ADD COLUMN IF NOT EXISTS course_id uuid REFERENCES public.courses(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS attendance_logs_course_idx
  ON public.attendance_logs (course_id);
