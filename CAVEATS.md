# Caveats — feat/ict1-quizzes-and-lockin

Known limitations, assumptions, and deliberate trade-offs for this change set.
Kept current through the review loop; entries are addressed or accepted before merge.

## ICT1 slide-based quizzes (Quiz 1–3, 5–6)

- **Hermes review (commit 9ada899) — accepted findings**: upserts use SELECT-then-INSERT
  rather than `ON CONFLICT` (migrations run once, sequentially via `scripts/migrate.ts`;
  a `(course_id, title)` unique index is deliberately not added because soft-deleted quiz
  rows may share a title). Magic numbers (15 min / 10 items / +14d) kept literal — seed
  convention across all existing quiz seeds. `options` jsonb is cast from SQL string
  literals we author (not external input), so no `IS JSON` guard needed. If ICT1 is
  missing the seed NOTICEs and skips — intentional, never guess.

- **Quiz 4 / Week 5 (Online Collaboration Tools) intentionally skipped** — the task
  numbering maps Quiz 1→Week 2 … Quiz 6→Week 7 and omits Quiz 4. Week 5 slide exists
  in `docs/ICT1/` but has no quiz. Add later if wanted.
- **Replace-by-title upsert**: if an active quiz titled 'Quiz N' exists on ICT1 (e.g.
  the TVE100 clone), its question set is replaced with the slide-based set. Per-row
  `duration_minutes`/`question_count` are refreshed (15 / 10) so a stale clone config
  (e.g. `question_count = 20`) cannot over-draw a 10-item bank. **Availability/release
  state (`opens_at`, `closes_at`, `score_released`, `answer_key_released`) is preserved
  on existing rows** — teacher-set windows survive re-runs.
- **New quizzes seed `opens_at = NULL` (open now) and `closes_at = now() + 14 days`**
  (repo seed convention, same as the IT10 seeds). Nothing was specified for windows;
  teachers can adjust in the UI.
- **No slide attachments**: the new pptx files in `docs/ICT1/` are not in Supabase
  storage, so the seeded quizzes carry no `attachments`. Upload via the app if handouts
  are wanted.
- Question content is grounded strictly in the extracted slide text — no external facts.

## Migration hygiene

- Quiz seeds renamed to `20261012000011–15_*` (were `20261012000001–05_*`) to avoid
  **version-prefix collisions** with the existing `20261012000001_enroll_liveuser_courses`
  / `20261012000002_update_liveuser_student_profile` migrations. `scripts/migrate.ts`
  tracks by full filename (collision harmless there), but `supabase db push`
  (`.github/workflows/migrate-prod.yml`) versions by prefix and would fail. No duplicates
  remain.

## Lecture TLE 105 removal

- **Hard delete**, including previously soft-deleted rows of that course. Matched by
  `code = 'TLE 105'` → `title ILIKE 'LECTURE_TLE 105%'` fallback; **ICT1 and TVE100 are
  explicitly guarded and can never be deleted**. Idempotent (NOTICE + skip when absent).
- `attendance_logs` is not course-scoped (keys on `student_id`) and `notification_logs` /
  `audit_logs` carry no course FK — those rows are deliberately untouched.
- `PRODUCTION_APPLY_V3.sql` no longer creates/resyncs the lecture course; the blocks are
  replaced with pointers to `20261012000010_remove_lecture_tle105.sql`. `PRODUCTION_APPLY.sql`
  never targeted the lecture course and is unchanged.

## Breadboarding in simulation questions

- **DB trigger** (`enforce_breadboarding_in_sim_questions`) rejects `lab_task = true`
  rows whose question text lacks wiring terms (breadboard/wire/wiring/jumper/resistor/
  pin-to-pin). Mirrors the Zod rule in `schemas.server.ts` (create + update paths).
- **Backfill** appends one wiring sentence to 2 seeded Part IV rows
  (`20261010000005` pos 76–77) whose question text lacked wiring terms. **Rubrics
  (`correct_answer`) untouched**; no circuit specs invented. Simulation Task A/B were
  already compliant.
- Rule text is keyword-based — a pedagogically odd phrasing that happens to contain a
  wiring term passes; this is an enforcement floor, not a content-quality gate.

## Kiosk lockdown (app-wide)

- **Central server flag, not per-browser**: `app_settings.kiosk_lockdown` (boolean).
  Read by any signed-in session; written by admins only (validated + `writeAuditLog`).
  localStorage `AdminConfig` was rejected — it cannot reach every student device.
- **Fail-open by design**: missing row / DB read error ⇒ lockdown OFF. A fresh DB or
  transient blip never traps students on a kiosk. Trade-off: a settings outage silently
  disables lockdown.
- **Composition**: `useExamLock` mounts exactly once (`LockdownProvider` in the student
  layout). Routes register *demands* (`exam` while taking, `kiosk` when student + setting
  on); mode resolution is **exam > kiosk > none** — one overlay at a time, exam copy wins
  during attempts (quiz behavior unchanged), kiosk copy otherwise. No double listeners /
  double wake locks.
- **Students only** — teachers/admins never locked. **Sign-out always works** and now
  exits element-fullscreen so the kiosk drops back to the sign-in screen.
- **Browsers without the Fullscreen API** (iPhone Safari) get input-blocking only — same
  degradation the exam lockdown already had; no new platform guarantee.

## Review triage (Hermes, per-commit 9ada899 / aca28b3 / 51c328b / 6f12ae7 / 8185a63)

No commit was rated "Needs changes". Dispositions:

- **Accepted, documented**: keyword regex is an enforcement floor, not a content-quality
  gate (see above); kiosk fail-open is silent-by-design (see above); magic numbers kept
  literal per seed convention; backfill sentence is generic by design.
- **Rejected as non-issues**: SELECT-then-INSERT upsert races (migrations run once,
  sequentially via `scripts/migrate.ts`; `(course_id, title)` unique index rejected —
  soft-deleted rows may share titles); `examActive`/`kioskActive` "races" (single-threaded
  store; React batching cannot interleave demand updates); `=== true` strictness in
  `shouldKioskLockdown` is deliberate (rejects `"true"` strings from a JSON column);
  `ORDER BY created_at LIMIT 1` on course lookup is deliberate determinism.
- **PR #56 review (Hermes) — "Minor issues"**: (1) `questionUpdate` superRefine could
  not see the stored `lab_task` when a patch omitted it — **closed**: `updateQuestion`
  (question-bank.server.ts) now validates the effective post-update state before writing;
  the DB trigger remains the backstop. (2) Client `logAudit` looked like a possible
  duplicate of the server `writeAuditLog` — **confirmed**: `logAudit`
  (src/lib/settings.ts) writes localStorage only (presentational demo panel); the server
  audit trail (`writeAuditLog`) is the single persistent record.

- **Accepted, minor (deliberate)**: `document.exitFullscreen().catch(() => {})` swallows
  benign "not fullscreen" rejections; `RAISE NOTICE` visibility matches every other seed
  migration in this repo; `refetchInterval: 60s` matches the kiosk-polling pattern in
  `__root.tsx`.
- **Deferred (tooling, out of scope)**: CI check for migration version-prefix collisions
  (manual guard applied in this PR — renames to `20261012000011-15`); post-migration
  orphan checks; parameterized refactor of quiz seed templates.

## Environment / validation

- **Docker daemon is not running on this machine**; local DB validation uses PGlite
  (`bun run db:pglite`). CI's e2e job runs real `postgres:16-alpine` — that is the
  parity gate for PG behavior. Run `bun run db:up && bun run db:migrate` against Docker
  Postgres before production if closer parity is wanted.
- Not deployed to production (`miow.joalvers.tech`) — awaiting explicit go.
