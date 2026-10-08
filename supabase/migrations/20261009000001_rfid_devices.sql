-- Phase 3 — RFID device registry: per-device API keys + heartbeat status.
-- Additive + idempotent: safe to re-run, zero-downtime.

CREATE TABLE IF NOT EXISTS public.rfid_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  location text,
  key_prefix text NOT NULL,
  key_hash text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS rfid_devices_key_prefix_idx
  ON public.rfid_devices (key_prefix);

ALTER TABLE public.rfid_devices ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'rfid_devices' AND policyname = 'service_role full access'
  ) THEN
    CREATE POLICY "service_role full access" ON public.rfid_devices
      FOR ALL TO service_role USING (true) WITH CHECK (true);
  END IF;
END $$;

GRANT ALL ON public.rfid_devices TO service_role;
