-- 20261012000030: App-wide kiosk lockdown setting (admin toggle).
--
-- WHY: shared/kiosk student devices need an app-wide lockdown (fullscreen +
-- input blocking + wake lock, the same hard lock the exam flow uses) that an
-- admin can turn on centrally. The flag must be readable by every student
-- session on every device, so it is server-persisted — the localStorage
-- AdminConfig is per-browser and cannot reach other kiosks.
--
-- Additive + idempotent: safe to re-run, zero-downtime. Boolean flags keyed by
-- name, so future admin toggles can reuse this table without new migrations.

CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'app_settings' AND policyname = 'service_role full access'
  ) THEN
    CREATE POLICY "service_role full access" ON public.app_settings
      FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

GRANT ALL ON public.app_settings TO service_role;

-- Seed the kiosk lockdown flag as OFF (idempotent).
INSERT INTO public.app_settings (key, enabled)
VALUES ('kiosk_lockdown', false)
ON CONFLICT (key) DO NOTHING;
