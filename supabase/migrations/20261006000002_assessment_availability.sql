-- P2a — assessment availability windows (user-signed policy 2026-10-06).
--
-- quizzes (worksheets/prelims) and assignments gain an optional availability
-- window:
--   opens_at  NULL = open now (backward compat: every existing row stays open)
--   closes_at NULL = no hard close from this column
--
-- Deadline policy (user decision — HARD-BLOCK, no late flag, no overwrite):
-- attempts and submissions are rejected before opens_at and after the item's
-- earliest configured deadline (quizzes: closes_at; assignments: due_date and/or
-- closes_at). Enforcement lives in TypeScript (src/lib/server/availability.ts)
-- because the pg compat layer cannot express `IS NULL OR <=` filters.
--
-- Additive + idempotent: safe to re-run, zero-downtime. Apply to prod BEFORE
-- the UI ships (Gate-1 amendment #4).

ALTER TABLE public.quizzes
  ADD COLUMN IF NOT EXISTS opens_at timestamptz,
  ADD COLUMN IF NOT EXISTS closes_at timestamptz;

ALTER TABLE public.assignments
  ADD COLUMN IF NOT EXISTS opens_at timestamptz,
  ADD COLUMN IF NOT EXISTS closes_at timestamptz;
