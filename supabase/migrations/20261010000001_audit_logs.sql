-- Server-side audit log: authoritative, cross-browser record of privileged
-- actions (role changes, deletions, enrollment, device registry, grades…).
-- Replaces reliance on the per-browser localStorage trail for accountability.
-- No FK to profiles on purpose: audit rows must survive user deletion.
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id uuid,
    actor_name text,
    actor_role text NOT NULL DEFAULT 'system',
    action text NOT NULL,
    detail text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs (created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'audit_logs' AND policyname = 'service_role full access'
  ) THEN
    CREATE POLICY "service_role full access" ON public.audit_logs
      FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

GRANT ALL ON public.audit_logs TO service_role;
