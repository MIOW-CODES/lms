-- Correct the live announcements — they were all placeholder/demo content.
--
-- User decision (2026-10-15): replace the stale/incorrect demo notices with
-- accurate notices for the real 1st Quarter IT10 assessment schedule.
--   * Removed (nothing in the system corroborates these; all seeded placeholders):
--       - "Classes Suspended Tomorrow Due to Typhoon Signal"  (fake urgent closure)
--       - "Second Quarter Exam Schedule Released ... September 7-11" (wrong quarter + dates)
--       - "Intramurals 2026: Opening Parade This Friday"      (fake event)
--       - "Robotics Club Meeting This Wednesday"              (fake event)
--   * Added: the correct 1st Quarter IT10 exam + quiz schedule
--     (Friday, 16 Oct 2026, 08:00–10:00 Asia/Manila — matches the assessment
--      window set in 20261015000001).
--
-- Idempotent: DELETE by the four fixed demo ids; UPSERT the two real notices.
BEGIN;

DELETE FROM public.announcements
 WHERE id IN (
   'aa000000-0000-4000-8000-000000000001',
   'aa000000-0000-4000-8000-000000000002',
   'aa000000-0000-4000-8000-000000000003',
   'aa000000-0000-4000-8000-000000000004'
 );

INSERT INTO public.announcements
  (id, title, content, category, target_audience, author_id, created_at, pinned)
VALUES
  ('aa000000-0000-4000-8000-000000000010',
   '1st Quarter Examination — Information Technology 10',
   'The 1st Quarter Examination for Information Technology 10 is scheduled on Friday, October 16, 2026, from 8:00 AM to 10:00 AM. It covers Arduino fundamentals, basic electronics, and the resistor color code. Review your course materials and be on time.',
   'academic', 'students', 'b0000000-0000-4000-8000-000000000003', now() - interval '2 hours', true),
  ('aa000000-0000-4000-8000-000000000011',
   'IT10 Quizzes — Friday, October 16',
   'Your IT10 quizzes (Arduino Part 2, Resistor Color Code, and Programming with Arduino) are open only on Friday, October 16, 2026, during the same 8:00-10:00 AM window as the 1st Quarter Examination. Complete them within this window.',
   'academic', 'students', 'b0000000-0000-4000-8000-000000000003', now() - interval '90 minutes', true)
ON CONFLICT (id) DO UPDATE SET
  title           = EXCLUDED.title,
  content         = EXCLUDED.content,
  category        = EXCLUDED.category,
  target_audience = EXCLUDED.target_audience,
  author_id       = EXCLUDED.author_id,
  pinned          = EXCLUDED.pinned;

COMMIT;
