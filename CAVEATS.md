# Caveats — feat/ict1-quizzes-and-lockin

Known limitations, assumptions, and deliberate trade-offs for this change set.
Kept current through the review loop; entries are addressed or accepted before merge.

---

# Caveats — batch 2 (feat/ict1-weekly-quizzes-and-fixes)

## ICT1 weekly quiz restructure (Quiz 1–7 + Final Exam)

- **Quiz N = Week N** (new convention): Quiz 1–4 grounded in TVE100 Week 1–4 PDFs
  (Introduction/TVET System, Teacher as Professional, Teacher & Community, School
  Culture), Quiz 5–7 in ICT1 Week 5–7 decks (Online Collaboration, LMS, Multimedia).
  Supersedes the batch-1 numbering (which skipped Quiz 4 and mapped Quiz 1→Week 2).
- **Reset migration first** (`20261013000000`): soft-deletes the old active `Quiz 1…7`
  rows (wrongly-based content + attempt history preserved but hidden), then the new
  set is inserted. Old rows never hard-deleted. PRELIM/FINAL rows never matched.
- **Legacy all-caps clones** (`20261013000030`): the TVE100 assessment clone left
  `QUIZ 1`…`QUIZ 4` rows (all-caps titles) that the reset's mixed-case match missed —
  they duplicated the weekly set in the UI (13 cards instead of 9). Soft-deleted with
  a double guard (`title = upper(title)` AND `^QUIZ [0-9]+$`) so the live mixed-case
  set can never be caught. These are the "quiz 1-3" the user asked to remove.
- **Weekly quizzes: 10 questions / 20 minutes** each (question count unspecified; kept
  the 10-item convention). **FINAL EXAMINATION (Coverage: Weeks 1-7): 100 questions /
  60 minutes**, authored as two range-scoped halves (1–50 TVE100 weeks, 51–100 ICT1
  weeks) so parallel seeding never collides.
- **Availability**: fresh rows get `opens_at NULL, closes_at now()+14d` (repo seed
  convention); existing rows keep availability/release state on re-runs.

## Materials on quizzes

- **ICT1** (`20261013000020`): each quiz gets its week's file copied **from the
  PRELIM EXAMINATION row's attachments** (files already in Supabase storage — no
  re-upload, URLs copied verbatim). Matching is by exact attachment `name`; a stored
  name mismatch (spelling/underscore) skips that file with a NOTICE. Locally the
  migration NOTICE-skips (prelim attachments exist only in prod storage) — expected.
- **IT10** (`scripts/attach-it10-materials.ts` + CI job): uploads the 5 source PDFs
  from the repo root to `course-materials` and attaches them per quiz; `1st Quarter
  Exam` gets the 4 study PDFs as reviewers. **Teacher copy (answer key), the exam
  .docx (live questions) and the TOS are hard-blocked from ever being attached.**
  Idempotent (skip by attachment name). **"Programming with Arduino.pdf" is 29.3 MB**
  — over the app's 25 MB UI cap but under Supabase's 50 MB; the script uploads it with
  an explicit warning (UI drag-drop of that one file would be rejected).
- Prod service-role key is not machine-readable locally (vercel env redacts secrets);
  the CI `workflow_dispatch` job derives it from `SUPABASE_ACCESS_TOKEN` at run time.

## Student course-visibility leak (verified, fixed)

- Confirmed real: `listCourses()` returned the **entire catalog to any session** and
  5 student pages filtered client-side with `|| grade_level` fallbacks — students saw
  every course in their grade level regardless of enrollment.
- Fix is **server-side** (student ⇒ enrolled courses only; staff keep full catalog).
  Quiz/assignment/material access was already enrollment-guarded server-side (only
  course shells leaked). Secondary fix: `listCourseMeetings` now requires enrollment
  for students (timetable of arbitrary courses was readable by id).
- **Verified in prod UI** (post-deploy): a student with zero enrollment rows now
  correctly sees **zero** courses (before the fix they saw every same-grade course).
  Example: Benejol (2nd Yr · B8) is not in the ICT1 roster ("0 of 46 learners") and
  her Courses page is empty — correct, not a regression. If B8 students should
  access the ICT1 lab, that is an admin "Enroll students" data action, not code.

## Course-list mismatch — over-broad seed enrollments (data, not code)

- **Symptom** (user report): "students see all courses / courses don't correspond
  to their enrolled course." **Not a visibility-code bug** — `listCourses`,
  `listQuizzes`, `listAssignments`, grades, meetings and materials are all
  enrollment-gated server-side and the student pages double-filter.
- **Root cause**: two seeds enrolled far more students than intended, so the
  course list legitimately contained courses that weren't the learner's class:
  - `20260901000000_grade10_seed.sql` enrolled **every** student into **IT10**
    (`WHERE p.role='student'`, no grade filter). IT10 is a Grade 10 subject.
  - `20261010000009_seed_iae106_*.sql` + `seed-iae106.server.ts` enrolled
    **every** student into **IAE 106**, though both described a College-2nd-Year
    / BTLED / B8 / test-account cohort the SQL never actually applied.
  - (Separately) `20261012000001_enroll_liveuser_courses.sql` deliberately puts
    the demo account `test@g.msuiit.edu.ph` in **all** courses. Verifying the
    visibility fix while signed in as that account in "student" role-view shows
    the full catalog **by design** — use a real student account to verify.
- **Fix (code)**: the two seed queries now scope to the intended cohort —
  IT10 ⇒ `grade_level = 10`; IAE 106 ⇒ `grade_level = 14` OR `section ILIKE
  'BTLED%'` OR `section = 'B8'` OR test accounts (`2026-0000` /
  `test@g.msuiit.edu.ph`). Re-seeding a fresh DB is now correct.
- **Fix (data)** `20261013000080_cleanup_overbroad_course_enrollments.sql`:
  repairs already-seeded databases by deleting IT10/IAE 106 enrollments outside
  those cohorts. Scope-limited to those two course codes; staff rows untouched;
  idempotent (`DELETE ... USING profiles`, `RAISE NOTICE` counts). Verified
  against PGlite: an injected out-of-cohort learner enrolled in both courses is
  removed on run (2→0) and 0 out-of-cohort rows remain afterward.
- **Assumption**: college years map to `grade_level = 12 + year` (College 2nd
  Year = 14), and `section` carries program-section strings (`BTLED-IA`,
  `BTLED-HE`, `B8`) — matches the ICT1 roster seed convention. If a student is
  wrongly removed, the migration footer shows the one-line re-enroll undo.
- **Manual verify still wanted in prod**: sign in as a real ICT1 student and
  confirm the course list shows only their actual courses.

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
  audit trail (`writeAuditLog`) is the single persistent record. Re-review
  (after `97aaa29`) rated the PR **LGTM** pending two verifications, both now
  confirmed: (a) student route tree is fully nested under `dashboard.student.tsx`
  (all 7 pages are its children; `/` redirects to `/auth`) so no student-reachable
  route escapes the lockdown; (b) the `db` client runs as service_role / the
  `DATABASE_URL` table owner (see the DB role note in `app-settings.server.ts`) —
  both see through the `app_settings` RLS policy. Accepted suggestions left as-is:
  typed error for `updateQuestion`, backfill length guard (2 rows, sub-2000 chars),
  60s disable-propagation delay.

- **Accepted, minor (deliberate)**: `document.exitFullscreen().catch(() => {})` swallows
  benign "not fullscreen" rejections; `RAISE NOTICE` visibility matches every other seed
  migration in this repo; `refetchInterval: 60s` matches the kiosk-polling pattern in
  `__root.tsx`.
- **Deferred (tooling, out of scope)**: CI check for migration version-prefix collisions
  (manual guard applied in this PR — renames to `20261012000011-15`); post-migration
  orphan checks; parameterized refactor of quiz seed templates.

## Review triage (Hermes, PR #57) — rating: LGTM

- Accepted, documented: double dotenv precedence in `attach-it10-materials.ts`
  (`.env` defaults, `.env.local` overrides, real env wins) is intentional.
- Accepted, future polish: explicit error logging on the `enrolledCourseIds`
  failure path; a dedicated `listAllCoursesForLookup()` instead of the neutral-caller
  pattern in chat-tools; retry/backoff in the workflow's key-derivation curl.
- Final-exam Part 1 range delete is attempt-safe: attempts snapshot question text
  into `results` jsonb; `quiz_questions` rows are re-seeded idempotently.
- SELECT-then-INSERT upsert races: non-issue — migrations apply once, sequentially.

## Environment / validation

- **Docker daemon is not running on this machine**; local DB validation uses PGlite
  (`bun run db:pglite`). CI's e2e job runs real `postgres:16-alpine` — that is the
  parity gate for PG behavior. Run `bun run db:up && bun run db:migrate` against Docker
  Postgres before production if closer parity is wanted.
- Not deployed to production (`miow.joalvers.tech`) — awaiting explicit go.
