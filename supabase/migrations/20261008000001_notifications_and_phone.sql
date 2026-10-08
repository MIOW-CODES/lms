-- Notification pipeline and profile phone support
-- Adds phone number to profiles and creates notification_logs audit table

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone text;

CREATE TABLE IF NOT EXISTS public.notification_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_email text,
  recipient_phone text,
  channel text NOT NULL, -- 'email' | 'sms'
  event_type text NOT NULL, -- 'announcement' | 'assignment' | 'worksheet' | 'quiz'
  title text NOT NULL,
  status text NOT NULL, -- 'sent' | 'failed' | 'mock'
  error text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notification_logs' AND policyname = 'service_role full access'
  ) THEN
    CREATE POLICY "service_role full access" ON public.notification_logs
      FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

GRANT ALL ON public.notification_logs TO service_role;
