# MIOW LMS: Code Audit, Local Database, and Orange Pi Deployment Plan

Prepared: 20 October 2026 (Asia/Singapore)

Repository: [MIOW-CODES/lms](https://github.com/MIOW-CODES/lms)

Target: Orange Pi Zero 3, 4 GB RAM, with the LMS at **https://akios.site** through **Nginx Proxy Manager (NPM)**.

Status: Whole-tree inventory and scan, risk-based source review, and targeted audit write-up completed against `eb370ea2b5f1724ffe90e5f58bcc1b9cff06b8b2`. Implementation is underway on this branch; section 0.14 records changes, validation, and pushed commits for each finding addressed. The target architecture is native PostgreSQL only, with local filesystem uploads and no hosted database provider, auth/storage dependency, or hosted migration workflow. The user confirmed Orange Pi + NPM remains the deployment target. GitHub Actions remain removed at the user's request. Orange Pi deployment remains blocked pending the listed fixes and target-environment verification.

## 0. Audit the entire repository before implementation

Required order: **retrieve and inventory source -> scan the full tracked tree -> record findings in this file -> define a targeted approach for every finding here -> implement and verify fixes -> proceed with database and deployment work**. Do not start fixing findings before the whole-tree scan is complete. Temporary harnesses and synthetic fixtures are acceptable; never expose production records or secrets in audit outputs.

This file is the audit scope, coverage, result, remediation, and release-plan record. Scan all tracked application code, routes, server functions, database/storage adapters, SQL, tests, scripts, build/container configuration, CI workflows, docs, and static assets. Check correctness, edge cases, privacy, security, performance, accessibility, maintainability, and operational failures. Section 0.13 reports the completed baseline scan and its limits; no finding is marked verified fixed.

### 0.1. Inventory and architecture map

- Record revision, branch, runtime/dependency versions, OS, and DB setup. Reconcile every tracked path; include hidden files, tests, workflows, migrations, and scripts. Explicitly classify generated, vendored, binary, or sensitive material.
- Map routes, server functions, trust boundaries, roles, data flows, database/storage access, third-party services, background work, and deployment entry points. Trace browser actions through authorization to DB/file effects.
- Build role/action cases for anonymous users, students, teachers, administrators, and hardware clients, including cross-student, cross-course, and cross-role attempts.
- Read repository instructions, caveats, prior audits, TODO/FIXME markers, and known limitations. Check whether old issues remain reproducible.
- Locate unused code, duplicate behavior, inconsistent validation, broad catches, silent fallbacks, and stale docs; verify callers before recommending removal.

### 0.2. Reproducible checks and supply chain

- Inspect package scripts, install hooks, lockfiles, executable utilities, image entry points, and workflow permissions before running code. Keep production credentials out of the audit host.
- Run typecheck, lint, unit, integration, browser, database migration, and production build checks. Identify which files each script actually selects. Record exit status, environment, failures, and omissions.
- Review resolved dependencies and base images for current advisories, support status, install behavior, and ARM64 compatibility. Do not claim exploitability without checking use/reachability.
- Review CI triggers, deployment/migration triggers, artifacts, caches, third-party actions, permissions, secrets, and branch coverage.
- Scan current source/config/build assets and Git history for credentials and private data. Redact values in evidence. If history scanning is blocked, report the gap.

### 0.3. Authentication, authorization, and privacy

Trace every protected route, RPC, download, and mutation to server-side authorization. Test URL/object/body/role changes, anonymous requests, and cross-account access. Cover PIN/login edge inputs (empty, whitespace, Unicode, leading zeros, long strings, disabled/deleted users, legacy hashes, temporary credentials, concurrent credential changes), sessions, expiry, tampering, revocation, role changes, key rotation, cookie flags, restarts, CSRF, CORS, redirects, enumeration, rate-limit failures, spoofed proxy headers, and alternate endpoint bypasses. Inspect student records, grades, answer keys, attendance, exports, logs, analytics, AI requests, errors, client bundles, and prefetched responses for leakage.

### 0.4. Inputs, APIs, imports, and file storage

Inventory all externally controlled query, route, form, JSON, server-function, filename, upload, document, AI, and hardware inputs. Test missing/null/wrong types, unexpected properties, invalid IDs, duplicate parameters, negative/out-of-range numbers, malformed encodings, huge bodies, and unexpected content. Review SQL parameterization, HTML/Markdown, URLs/redirects, filesystem paths, and process execution. Test traversal, absolute/encoded paths, sibling-prefix roots, symlinks, Unicode, long names, bucket selection, ownership, replacement, deletion, MIME mismatch, active content, corrupt/expanded documents, duplicate names, concurrency, partial writes, permissions, disk full, and download headers. Review import SSRF/private-network access and spreadsheet formula injection.

### 0.5. Database, migrations, and persistence

Audit every SQL file and DB access path: constraints, nullability, defaults, keys, indexes, cascades, functions, triggers, grants, RLS, and privileged execution. The end state is **native PostgreSQL only**; test retained queries against PostgreSQL rather than provider parity. Cover filter/join/select/count/pagination/order/upsert/conflict/RPC/transaction/error semantics, empty/missing/stale data, uncertain commits, lost updates, concurrency, deadlocks, and pool exhaustion. Apply migrations to empty and imported schemas, rerun, interrupt, and test ledger recovery. Review duplicate IDs, seed and destructive operations, optional one-time data import, backups, and restores.

### 0.6. LMS rules and time boundaries

Exercise duplicate enrollment, dropped students, changed teachers, archived courses, assessment types/answers/retakes, partial and duplicate submissions, concurrent tabs, disconnect/retry, timer/deadline boundaries, clock skew, attempt limits, missing/zero scores, rounding, changed assessments, attendance/RFID replay and leading zeros, notification/provider failure, and idempotent bulk imports. Verify school timezone and UTC persistence across midnight, month/year changes, leap days, and inclusive/exclusive cutoffs.

### 0.7. Frontend, PWA, accessibility, and browser behavior

Test loading/empty/success/forbidden/not-found/validation/offline/slow/timeout/error states; double submits, stale cache, navigation during mutation, response ordering, cancellation, refresh/back, optimistic rollback, SSR/hydration and missing optional config. Test service-worker upgrades, account changes, logout and offline caching on shared devices. Check keyboard/focus/labels/errors/dialogs/contrast/small screens/touch/reduced motion, plus camera/RFID permission failures.

### 0.8. External integrations

Inventory data, credentials, scopes, callback/origin rules, quotas, and server/client boundaries. Test missing/invalid/revoked credentials, timeouts, drops, throttles, malformed responses, interrupted streams, retries, and outages. Review AI prompt injection, untrusted imports, rendered output, permissions, answer visibility, student data disclosure, and local functionality when optional services are down.

### 0.9. Performance and operations

Profile queries and representative workflows for missing indexes, N+1, large/unpaginated responses, parsing cost, memory leaks, unbounded caches, timers, and open resources. Measure realistic concurrent login, assessment save/submit, attendance, import, and upload load: latency, errors, CPU, temperature, RAM, DB connections, storage, and disk. Test DB/network failure, slow queries, disk-full/read-only, process termination, restarts and recovery. Review startup/shutdown, readiness, bounded/redacted logs, backup failures, privileges, image contents, build secrets, volume ownership, exposed ports, NPM trust, and Pi hardware.

### 0.10. Finding format and remediation rule

Each issue needs a stable ID, severity, confidence, location, trigger, expected/actual behavior, impact, evidence or reproduction, targeted task, dependencies, data/config/security/deployment/rollback implications, regression cases, acceptance criteria, status, effort, and reason for any deferral. Distinguish confirmed defects from unverified hypotheses. Every finding must map to a concrete task or explicit disposition in section 0.13; do not present generic checklists as issue-specific fixes.

| Severity | Meaning                                                                                 | Release consequence                                     |
| -------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| Critical | Credible privileged compromise, broad sensitive-data exposure, or destructive data loss | Block until fixed and verified                          |
| High     | Material authorization, privacy, correctness, or reliability failure                    | Block until fixed and verified                          |
| Medium   | Bounded defect or specific failure with mitigation                                      | Fix before release where feasible; record residual risk |
| Low      | Minor usability or low-impact maintainability issue                                     | Track and document deferral                             |

### 0.11. Scan and release gates

The whole-tree inventory and scan, risk-based review, and targeted write-up are complete for the baseline in section 0.13. A stronger file-by-file direct-review gate remains open: section 0.13 explains that not every line/document was manually read. Before implementation/deployment, resolve its identified gaps, exercise critical permission boundaries, record all failed/skipped checks, and review changed code/artifacts against the findings. This plan is not deployment approval.

### 0.12. Subsequent implementation gate

Fix and verify Critical/High findings before release. Run required checks on the final revision; prove native DB migration/restore behavior in a disposable environment; repeat regression review on changed files and affected callers. Keep hardware-specific ARM64, thermal, routing, reboot, and backup tests explicit for the Pi. Update each finding in this file with commit/test evidence.

### 0.13. Audit results and targeted remediation approach

**Audit status at plan creation:** A repository-wide inventory and static scan, direct review of high-risk first-party code and deployment paths, test/build checks, SQL migration exercise, and document/binary scan were completed for the baseline below. This is a planning audit, not a certification that every line has received manual review. At that point no application fixes had been made. Findings marked as hypotheses remain unconfirmed. Section 0.14 supersedes that baseline for remediation progress.

**Architecture decision:** The finished application will use PostgreSQL as its only database. Remove Supabase SDK usage and provider selection, Supabase Auth/Storage assumptions, Supabase-only shims/roles/policies, Supabase environment variables, and the Supabase production migration workflow. Keep the LMS's own signed-session and bcrypt/PIN authentication, storing its records in PostgreSQL. Use the app's local persistent filesystem for uploaded files. If existing hosted data must be retained, Supabase may be used only as a temporary, one-time export source under controlled conditions; it is not a runtime, deployment, migration, or synchronization dependency.

#### A. Audited baseline and coverage

| Item                    | Result                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Repository / revision   | `MIOW-CODES/lms`, `eb370ea2b5f1724ffe90e5f58bcc1b9cff06b8b2`; work branch `codex/orange-pi-local-postgres`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Platform and tools      | Windows x64; Bun 1.4.0; Node 26.3.0; dependency install with `bun install --frozen-lockfile --ignore-scripts`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Inventory               | 492 tracked files reconciled with Git; 269 TypeScript/TSX files (~55,348 lines), 141 SQL files (139 migration files plus two apply bundles; ~9,495 lines), three Python scripts (~1,434 lines), 21 PDFs, six PPTX, and one DOCX. Other source, assets, configuration, tests, workflows, and documentation were included in the tracked-tree scan.                                                                                                                                                                                                                                                                              |
| Review approach         | Tracked-file enumeration; whole-tree text/pattern scans; direct review of database, auth, authorization, upload/download, API, build, container, migration, CI, and deployment paths; route/data-flow and graph-assisted structural mapping; test and build execution; text extraction from office documents and PDF pages. The graph index contained 3,584 nodes and 12,875 edges, with 128 partial parses and 12 deliberately unindexed files. Graph output was used as a navigation aid, not evidence of full semantic coverage.                                                                                            |
| Coverage qualification  | Every tracked path was inventoried and included in whole-tree scans where its format allowed. High-risk paths were directly inspected. A file-by-file manual read of all ~55k TypeScript lines and all document contents was not completed; generated, binary, and low-risk content was handled by provenance/consumer review or extraction/scanning. This limits assurance and must be addressed in the implementation review where code is changed. Student-identifying migration filenames are intentionally omitted from this public plan; reproduce the private filename map with `git ls-files` at the audited revision. |
| Sensitive-data handling | A roster-like PDF, historical reports/caveats, and student/account-specific SQL changes were detected. Their personal values, account identifiers, credentials, and identifying migration filenames are intentionally not reproduced here. The report itself does not disclose those values.                                                                                                                                                                                                                                                                                                                                   |
| Database availability   | No `psql`, PostgreSQL server, Docker, or browser test runtime was available. A temporary in-process PGlite harness with compatibility stubs applied all 139 migrations and produced 34 public relations. That demonstrates limited SQL/schema compatibility only; it is not a native PostgreSQL 16 test, authorization proof, or acceptable final architecture.                                                                                                                                                                                                                                                                |

The exact path inventory is reproducible from the audited Git revision. It is not copied as a 492-row list into this public document because a subset of tracked filenames themselves contain student-identifying information. The coverage register groups the inventory by review method and risk; it does not claim that every file was read line by line.

| Coverage group                                  | Inventory / scan method                                                                                                           | Status and limitation                                                                                                                                                        |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Application TypeScript/TSX                      | Counted and whole-tree scanned; directly reviewed high-risk auth, DB, route, storage, API, and server paths                       | Broad scan complete; complete manual line-by-line review remains a follow-up during remediation                                                                              |
| SQL migrations / apply bundles                  | All 141 files inventoried and migration chain exercised in PGlite with compatibility stubs                                        | Syntax/schema exercise only; convert all SQL to native PostgreSQL and repeat on PG16                                                                                         |
| Tests and scripts                               | Inventoried; package script selection inspected; relevant test suite, typecheck, build run                                        | Root database integration suites are not selected by the default `test` script; CI must include them                                                                         |
| Build, Docker, Compose, CI, workflows           | Directly inspected relevant files, including image build context, current Postgres setup, and migration workflow                  | Confirmed deployment gaps; future implementation needs ARM64 and native PG testing                                                                                           |
| Markdown, PDF, Office files                     | Text extracted from 42 office/text documents (~53 MB) and 420 PDF pages; sensitive-value scan performed without printing contents | Documents are not exhaustively human-reviewed; document sanitization is a release blocker                                                                                    |
| Generated, vendored, other binary/static assets | Tracked inventory and consumer/provenance review; binary file classes counted                                                     | Their full content is not represented as source review; inspect any asset that enters production or contains records                                                         |
| Git history                                     | Attempted 394-commit secret/history scan                                                                                          | Incomplete: Windows Git failed during history/text conversion with an `NtCreateDirectoryObject` error. Repeat in a controlled Linux checkout before declaring history clean. |

#### B. Commands, scenarios, and results

| Check                              | Command / environment                                             | Result                                                                                                                                                                                                | Limitation / follow-up                                                                                                                                                          |
| ---------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Dependency install                 | `bun install --frozen-lockfile --ignore-scripts`                  | Passed; 1,026 packages installed                                                                                                                                                                      | Install lifecycle scripts were intentionally disabled                                                                                                                           |
| Types                              | `bun run typecheck`                                               | Passed                                                                                                                                                                                                | Does not validate runtime authorization or PostgreSQL behavior                                                                                                                  |
| Unit tests                         | `bun run test`                                                    | Passed: 481 tests, 2,065 expectations, 40 files                                                                                                                                                       | Script runs `bun test src/`; root `tests/brand.test.ts` and `tests/integration/*.database.test.ts` are not included                                                             |
| Lint                               | `bun run lint`                                                    | Failed under Windows CRLF checkout because Prettier reported `Delete CR`; adjusted `bunx eslint . --rule 'prettier/prettier: [error, { endOfLine: auto }]' --no-warn-ignored` passed with 25 warnings | Preserve both results; resolve formatting policy in implementation                                                                                                              |
| Production build                   | `bun run build`                                                   | Passed                                                                                                                                                                                                | Vite noted redundant `vite-tsconfig-paths`; PWA precache was 549 entries / 16,441.8 KiB; build rewrote generated `src/routeTree.gen.ts`, which must remain restored to baseline |
| Database migration exercise        | Temporary PGlite harness against all 139 migrations               | Passed with Supabase-compatible schema/function/role stubs; 34 public relations created                                                                                                               | Not native PostgreSQL, not safe auth/RLS behavior, and not evidence that Supabase integration can remain                                                                        |
| Real PostgreSQL / Docker / browser | Tool availability check                                           | Not run: `psql`, Docker, PostgreSQL server, and browser runtime unavailable                                                                                                                           | Required before production readiness; target PostgreSQL is version 16                                                                                                           |
| Dependency audit                   | `bun audit`                                                       | Failed to resolve npm audit endpoint (`DNSResolveFailed`)                                                                                                                                             | No conclusion about current package advisories; rerun with network access and review reachability                                                                               |
| Static secret scan                 | Tracked text/config/common token patterns                         | No provider-token/private-key-shaped match was reported in scanned current-tree text                                                                                                                  | Pattern scanning is not proof of absence; history scan incomplete                                                                                                               |
| Document/privacy scan              | Extracted tracked Office/PDF text, 42 documents and 420 PDF pages | Sensitive education-record and account-specific material identified                                                                                                                                   | Keep a deployment blocker until reviewed, removed/anonymized, and re-scanned                                                                                                    |
| Git history scan                   | 394 commits attempted on Windows                                  | Incomplete due Git/textconv environment error                                                                                                                                                         | Repeat on Linux and assess any required history cleanup before publishing real data                                                                                             |

#### C. Findings register

Severity describes risk in the current baseline. Confidence distinguishes reproduced/static-confirmed conditions from hypotheses awaiting a browser or deployment test. Line references are to the audited revision and should be rechecked after edits.

| ID     | Severity / confidence  | Location and trigger                                                                                                                       | Evidence and impact                                                                                                                                                                                                                   | Targeted task / disposition                                                                         |
| ------ | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| AUD-01 | Critical / confirmed   | `docs/ITE241/CLASS LIST_SEM1 SY2026-2027.pdf`, historical reports/caveats, and student/account-specific migration group                    | Tracked materials include student-record-like and account-specific information. Public exposure can disclose sensitive education records.                                                                                             | T-01; sanitize/replace and re-scan before release; deployment blocker                               |
| AUD-02 | High / confirmed       | README/test account guidance; historical account/PIN migrations; `src/lib/role-view.ts:19-23,39,59`; `src/lib/server/auth.server.ts:76-80` | Shared/deterministic test credentials and a test identity role override can enable privileged viewing if present/enabled in production. Exact identifiers/secrets are omitted.                                                        | T-02; remove/rotate demo access and disable production role override; deployment blocker            |
| AUD-03 | High / confirmed       | `docker-compose.yml` Postgres initialization and app URL examples                                                                          | The development DB owner uses a predictable dev password and is the initialized superuser. Reusing it as app runtime magnifies credential leakage or SQL injection.                                                                   | T-03; separate locked-down runtime and migration roles                                              |
| AUD-04 | High / confirmed       | `src/integrations/db/client.server.ts:14-24,88-91,126`                                                                                     | Supabase environment variables can override `DATABASE_URL`, while file storage can independently be local, creating split backend state.                                                                                              | T-04; remove provider autodetection and all runtime Supabase branches                               |
| AUD-05 | High / confirmed       | `.github/workflows/migrate-prod.yml`; timestamp-prefixed migration files                                                                   | Workflow records only timestamp prefix; five prefixes each collide across two files. Partial failure/retry can skip a migration. It targets a hosted project through a Supabase API.                                                  | T-05; delete this workflow and implement native PG ledger/runner with unique full IDs and atomicity |
| AUD-06 | Medium / confirmed     | `src/integrations/db/client.server.ts:243-245,341`; attendance and audit callers                                                           | Query builder applies `.limit(n)` only for `n === 1`; dynamic limits otherwise yield unbounded lists.                                                                                                                                 | T-06; native query pagination and limit tests                                                       |
| AUD-07 | Medium / confirmed     | `src/lib/server/sessions.server.ts:121-130`; callers in profiles and logout                                                                | Revocation awaits a query but ignores returned `{error}`; stale sessions may persist while credential/role changes or logout appear successful.                                                                                       | T-07; propagate DB errors and verify persisted revocation                                           |
| AUD-08 | Medium / confirmed     | `src/integrations/db/storage.ts:27-30,63-66,83-85`                                                                                         | Raw string-prefix containment can accept a normalized sibling path sharing the bucket-root prefix.                                                                                                                                    | T-08; canonical path-relative containment, symlink and traversal tests                              |
| AUD-09 | Medium / hypothesis    | `src/routes/api/public/material.ts:80-82`                                                                                                  | Protected attachment response uses `private, max-age=300`; a shared browser may reuse a fresh URL across account changes. Server-side authorization exists, but browser replay is untested.                                           | T-09; reproduce with browser; set `no-store` or prove safe isolation                                |
| AUD-10 | Medium / confirmed     | `src/lib/server/hardware-auth.server.ts:49-58`; `src/routes/api/public/hardware/attendance.ts`                                             | Per-process limiter trusts first client-supplied X-Forwarded-For value and stores keys in an unbounded map; forged values can evade limits or grow memory. Request body is parsed before an explicit byte cap.                        | T-10; trust configured proxy chain, bound limiter, cap body, test forged headers                    |
| AUD-11 | Medium / confirmed     | `src/routes/api/chat.ts:112-123,179-197`                                                                                                   | JSON parsed without a byte limit; outbound call has no explicit timeout/abort; upstream error body is logged and token ceiling is high. Staff-only access/limiting reduce exposure.                                                   | T-11; bounded input, schema validation, timeout, token cap, redacted logging                        |
| AUD-12 | Medium / confirmed     | `package.json` test scripts; `.github/workflows/ci.yml`; security smoke workflow                                                           | Default tests omit root integration suites; CI trigger/PR coverage is narrow and security smoke targets an old host.                                                                                                                  | T-12; add PG16 native integration and branch/PR checks; post-release smoke at `akios.site`          |
| AUD-13 | Medium / confirmed     | `Dockerfile`, `docker-compose.yml`, repository root                                                                                        | No `.dockerignore`; build copies context broadly; runner lacks non-root user, explicit production environment, and health/readiness check; production app service is commented; dev DB credentials are weak.                          | T-13; hardened multi-arch app/DB Compose, internal networks, health, bounded logs and secrets       |
| AUD-14 | Medium / investigation | `src/routes/api/public/avatar.ts:14,30`                                                                                                    | Anonymous route accepts legacy 8-hex capability paths and returns immutable public caching; inventory and exploitability of old paths unknown.                                                                                        | T-14; inventory legacy files, remove/rotate old capability scheme or protect it                     |
| AUD-15 | High / confirmed       | `scripts/migrate.ts`, `supabase/migrations/**`, `src/integrations/db/client.server.ts`, package manifest                                   | Current migration runner creates Supabase auth/storage schemas, functions, roles and compatibility objects; SQL policies rely on `auth.uid()`-style assumptions and SDK is a runtime dependency. This is not a pure-native PG design. | T-15; convert schema, auth/RLS/grants, migration runner, SDK and env to native PG only              |
| AUD-16 | Medium / investigation | `vite.config.ts:75-86` and authenticated PWA workflows                                                                                     | Navigation caching exists; no proof that personalized data is cached in a way that crosses accounts. Offline/shared-device behavior remains untested.                                                                                 | T-16; test service-worker/account-switch/logout behavior and exclude private responses if needed    |
| AUD-17 | Medium / investigation | `src/server.ts:66`; hostname rollout                                                                                                       | HSTS uses `includeSubDomains; preload`; impact depends on all existing `akios.site` subdomains and browser preload behavior.                                                                                                          | T-17; inventory DNS/services; limit HSTS until subdomain HTTPS readiness is proven                  |

#### D. Targeted approach for every finding

**T-01 — Sensitive educational/account material (AUD-01; Critical; release blocker).** Before deployment or publishing a sanitized release, review every tracked PDF/Office document, historical report, caveat, seed, and account-specific migration. Remove records that are unnecessary; replace samples with synthetic data; convert only genuinely required generic schema changes into identity-independent migrations. Keep an approved private export outside the public repository. Run document extraction and secret/PII scans on the resulting tree and built image. Investigate the failed Git-history scan from a Linux checkout; if sensitive records were committed, prepare a separately reviewed history-remediation and fork/backup exposure plan. Acceptance: no real student/account records in current tracked files, built assets, image layers, or approved release history; privacy owner approves the sanitized inventory. Block all public deployment until verified.

**T-02 — Demo identity and role-view (AUD-02; High; release blocker).** Remove public/demo credentials from production documentation and seed paths. Delete/disable demo identities from production seed logic; provision the first administrator using a one-time out-of-band command; enforce unique credential rotation and first-login replacement where supported. Compile out or server-disable test role-view in production and remove its privileged bypass in `auth.server.ts`. Keep account-specific historical migrations out of the fresh-install chain; review Git history and use private one-time import steps only when retention is approved. Acceptance: production build has no test identity override; demo credentials cannot authenticate; ordinary users cannot reach an admin view; tests cover failed rotation, disabled account, stale session, and role changes.

**T-03 — Least privilege database roles (AUD-03; High).** Replace development Compose defaults with secret-backed local examples and a production Postgres service. Create an owner/migration role and a separate non-superuser runtime role; grant only schema/table/sequence/function access the app needs. Bind Postgres only to the app's private DB network, and use a distinct password per role. Add startup checks that reject missing/placeholder secrets and inspect effective privileges in PG16. Acceptance: runtime cannot create roles/databases/extensions or alter schema; migration role can perform required upgrades; 5432 is unreachable from WAN and proxy network.

**T-04 — Remove backend switching (AUD-04; High).** Delete `USE_SUPABASE`/credential-based backend selection and split DB/storage selectors. Remove all Supabase runtime dependencies and env reads. Startup must require a valid `DATABASE_URL` and connect only to the configured PostgreSQL service; local file storage must be the sole upload store. Fail closed when configuration is missing or malformed. Add tests that stale `SUPABASE_*` variables cannot change routing and that no Supabase hostname, client, or key reaches client bundles or production environment. Acceptance: application contains no runtime provider branch; all data and files resolve through the local PG/filesystem deployment.

**T-05 — Safe native migrations and CI (AUD-05; High).** Remove `.github/workflows/migrate-prod.yml` and its hosted API/token/project configuration. Design one native migration format with unique immutable IDs, duplicate-ID preflight, an advisory lock, and a ledger write in the same transaction as each migration where PostgreSQL permits. Define explicit handling for nontransactional statements. Apply one file at a time and make retry state unambiguous. Resolve colliding historical timestamp IDs before importing any ledger. Add failure injection after SQL and before ledger commit. Acceptance: concurrent runners serialize; failed transaction leaves neither partial schema nor a false applied marker; rerun is idempotent; the only automated migration target in CI is disposable PG16.

**T-06 — Bounded pagination (AUD-06; Medium).** Replace/repair the current compatibility query builder as part of T-15, or remove it in favor of parameterized native SQL/repositories. Ensure all list operations honor validated integer bounds, explicit ordering, and deterministic cursor/offset semantics. Audit attendance and audit log callers plus every `.limit()` usage. Acceptance: tests for zero, one, requested N, negative, non-integer, and over-maximum values show bounded SQL/results; large datasets do not trigger accidental full scans in API responses.

**T-07 — Session revocation errors (AUD-07; Medium).** Make revocation a native-PG operation that reports SQL errors. Callers changing credentials/roles or deleting a profile must not report success while old sessions remain valid; logout should clear its cookie but surface/log durable revocation failure with a clear retry/recovery policy. Prefer transactionally updating the profile and revoking sessions together when they share one DB operation. Acceptance: inject a returned DB error and connection loss; verify no false-success response, and verify old session denial after successful role/PIN/password change.

**T-08 — Storage path containment (AUD-08; Medium).** Replace string-prefix checks with canonical resolution plus `path.relative` boundary validation for every read/write/delete. Reject absolute paths, dot segments, encoded separators after decoding, and paths escaping the selected root. Evaluate symlink traversal with open flags or a storage layout that prevents following attacker-controlled links. Acceptance: traversal, sibling-prefix, Unicode/separator variants and symlink tests cannot read, overwrite, or delete outside storage; valid uploads/downloads continue to work on Linux ARM64.

**T-09 — Private material cache (AUD-09; Medium; hypothesis).** Reproduce using a real browser and service worker/cache enabled: account A opens/downloads an authorized attachment, logs out, account B requests the same URL within five minutes, including back navigation and offline cases. Inspect browser cache and server logs. Default to `Cache-Control: no-store` for student submissions, answer material, and other protected attachments unless an explicitly safe per-user cache strategy is demonstrated. Acceptance: account B never sees account A's bytes and server authorization runs for each private download; keep status as a hypothesis until test evidence exists.

**T-10 — Hardware limiter and request size (AUD-10; Medium).** In the single-Pi/NPM topology, use the `X-Real-IP` header that NPM overwrites with `$remote_addr`; ignore client-supplied `X-Forwarded-For`, validate the address, and verify the live NPM proxy-host configuration. Add a bounded in-process limiter with expiry and an entry ceiling; use a shared store only if multiple app replicas are introduced. Enforce both declared and streamed byte limits before JSON parsing and configure an NPM edge limit consistent with the LMS upload policy. Acceptance: forged forwarding headers cannot evade or grow the limiter; legitimate kiosk requests retain identity; oversized/malformed hardware payloads are rejected before JSON parsing. NPM's current default header mapping is documented in its [proxy.conf](https://github.com/NginxProxyManager/nginx-proxy-manager/blob/develop/docker/rootfs/etc/nginx/conf.d/include/proxy.conf); confirm the deployed version/configuration during rollout.

**T-11 — Chat request/upstream bounds (AUD-11; Medium).** Enforce byte limits before JSON parsing, validate a strict schema and per-field size/count limits, cap model tokens to a deliberate product maximum, add AbortSignal timeout and client-disconnect cancellation, and redact provider error bodies/credentials from logs. Acceptance: oversized, malformed, slow, interrupted, and failed upstream cases return bounded errors, free resources, and reveal no student/provider content in logs.

**T-12 — Tests and release gates (AUD-12; Medium).** Keep GitHub Actions removed as requested. Add explicit local scripts for unit, integration, e2e, lint, and build checks; run root database integration suites against PostgreSQL 16 with the same native migrations and roles as deployment before each release. Document that removing Actions leaves no GitHub-hosted regression gate unless the user later chooses a replacement. Replace stale security smoke host with `https://akios.site` only after release and require authenticated and unauthenticated checks appropriate to the route. Acceptance: the documented pre-release command set catches schema/permission regressions, no automated migration targets a hosted provider, and release smoke verifies TLS, headers, login, and core public endpoints.

**T-13 — Production container and Compose (AUD-13; Medium).** Add `.dockerignore`; use tested/pinned ARM64-compatible Bun/PostgreSQL image versions; set `NODE_ENV=production`; run app as non-root; keep build-time public Google IDs distinct from secrets; do not place private credentials in Vite args. Add health/readiness checks and controlled startup after migration success. Compose should provide `app`, `postgres`, and the existing/optional NPM on isolated networks: proxy can reach app only, app can reach database, database is not published. Persist PG data, uploads, NPM config/certificates; set resource/log limits and restart policy. Acceptance: build context excludes `.env`, `.git`, node_modules, records, and storage; multi-arch image runs on the Pi; health, restart, backup, and rollback rehearsals pass.

**T-14 — Legacy avatar capabilities (AUD-14; Medium; investigation).** Inventory existing avatar filenames and callers; determine whether any 8-hex paths correspond to private student imagery and whether callers depend on legacy behavior. Prefer authenticated authorization or rotate/remove the legacy path format; retain public immutable caching only for deliberately public, non-sensitive avatar assets under unguessable current identifiers. Acceptance: no private image can be retrieved by enumerable/legacy path; regression covers missing, stale, unauthorized, and valid public avatar cases.

**T-15 — Pure PostgreSQL architecture and schema conversion (AUD-15; High; foundational).** Remove `@supabase/supabase-js` from `package.json` and lockfile, all Supabase client imports/provider selection, Supabase env config, CLI/API dependencies, and storage/Auth calls. Replace the compatibility query builder with direct `pg` pool plus parameterized SQL. Replace the historic 139-file chain with a clean, identity-independent native schema baseline and unique forward migration IDs; do not replay account-, roster-, or grade-specific SQL as schema migration. Keep the LMS's server-side authorization model and grant the runtime role only the table, sequence, and function privileges required; do not add pooled-session identity or NULL-returning hosted-auth shims. Update import, dev-PG, Docker, tests, docs, and deployment commands. If retaining existing data, use a one-time controlled private export/import, transform schema and file references, compare counts/constraints/checksums, freeze writes for final copy, then revoke/remove source credentials and verify no ongoing connection. Acceptance remains a clean PostgreSQL 16 install/repeat upgrade with no hosted schemas, roles, SDK, env variables, or network calls; application auth and cross-student denials pass; stale hosted configuration cannot switch runtime.

**T-16 — PWA cache and account isolation (AUD-16; Medium; investigation).** Test service worker install/update, navigation fallback, query data, logout, shared-device account switch, and offline access using browser storage inspection. Exclude authenticated pages and private API responses from cache where persistence/replay is possible; clear account-scoped caches and client query state on logout. Acceptance: user B cannot see user A's records after logout/relogin, including offline and service-worker update paths. Keep as unconfirmed until reproduced.

**T-17 — HSTS rollout (AUD-17; Medium; investigation).** Inventory DNS records and all active subdomains before enabling `includeSubDomains` or preload. Confirm every affected hostname serves HTTPS with valid certificates and operators accept the long-lived browser policy. Start with HSTS limited to the apex/short max-age, then increase only after monitoring; omit preload/includeSubDomains until all subdomains are ready. Acceptance: all affected services remain reachable over HTTPS and there is a documented rollback/expiry plan.

#### E. Dependency-ordered work and release gates

1. **Privacy/security gate:** T-01, T-02, and Linux history scan. Stop if real records or credentials remain in the public tree, image layers, or release artifacts.
2. **Architecture and database foundation:** T-15 first. Specify native authorization/RLS model and migration baseline; then T-03, T-05, T-06, and T-07.
3. **Shared server boundaries:** T-04, T-08, T-09, T-10, T-11, T-14, and T-16. T-04 is subsumed by T-15's removal of provider switching but remains a named acceptance check.
4. **Automated release checks and packaging:** T-12 and T-13; run true PG16 tests and build ARM64 images.
5. **Public hostname rollout:** T-17, then NPM/DNS/HTTPS steps in sections 6-10 after all Critical/High items pass.
6. **Hardware readiness:** backup/restore, Pi restart, load and thermal checks, outside-network scan, and browser flows in section 11.

**Blockers at plan creation:** AUD-01/AUD-02/AUD-03/AUD-04/AUD-05/AUD-15 were open; actual PostgreSQL 16, browser, Git-history, ARM64, and Pi behavior were not verified. The application was not ready for deployment. Re-scan changed source and artifacts after implementation, and record each finding's pushed commit and verification in section 0.14.

## 0.14. Implementation log

The initial plan-only branch has moved into implementation. Each completed finding is recorded with its code commit and checks before work proceeds to the next finding. A partial mitigation is labelled as such; it does not close the finding or satisfy a deployment gate. Hardware, browser, and external-network checks remain open until run in their intended environments.

| Finding | Implementation status                                                                                                                                                                                                                        | Evidence and limits                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AUD-01  | Partial remediation pushed; the current tree has been sanitized, but public-history exposure remains unresolved.                                                                                                                             | Code commit `e8b7dd5` removes the flagged class list, reports, and two course-export PDFs whose identifier matched the class-list record. A text scan of remaining PDF/Office/HTML/Markdown documents found no email or student-ID match against the removed roster/account identifiers. Copies remain in earlier Git history; the prior history scan failed on this Windows host, so history review/remediation and privacy-owner approval remain release blockers.                                                                                                                                                                         |
| AUD-02  | Partial remediation pushed. The production role-view override and privileged identity bypass are removed, historical account-specific migration files are absent from the current tree, and a one-time first-admin bootstrap is implemented. | Code commits `9416d72` and `e8b7dd5`. `scripts/bootstrap-admin.ts` creates a random temporary password, stores only a bcrypt hash, sets `pin_must_change`, and refuses a second active administrator. PGlite verifies those properties. Existing Git history is unchanged, and real-PG first-login/rotation and all authorization-boundary checks remain open.                                                                                                                                                                                                                                                                               |
| AUD-03  | Role-separated database setup is implemented; real PostgreSQL verification remains open.                                                                                                                                                     | Code commit `e8b7dd5` adds separate bootstrap, migrator, and app roles; distinct required secrets; loopback-only host binding; app DML-only grants; private migration ledger; and an internal DB network. PGlite verifies existing/future-table DML, denied DDL/private-ledger access, and role restrictions. Docker and PG16 are unavailable on this host, so the init SQL and effective privileges still need testing on the target image.                                                                                                                                                                                                 |
| AUD-04  | Runtime provider selection and SDK dependency are removed from the current tree.                                                                                                                                                             | Code commits `9416d72` and `e8b7dd5`. The app uses only `DATABASE_URL` and local filesystem storage; `@supabase/supabase-js` and its lock records are removed. Whole-tree source/build scans found no client, hostname, or runtime environment dependency. README policy text and a migration preflight guard intentionally name forbidden hosted SQL concepts.                                                                                                                                                                                                                                                                              |
| AUD-05  | Native baseline and migration runner are implemented; PostgreSQL 16 acceptance is still open.                                                                                                                                                | Code commits `cf2f561` and `e8b7dd5`. The runner uses unique 14-digit IDs, SHA-256 checksums, an advisory lock, full applied-history preflight before pending work, transactional migration-plus-ledger writes, retry-safe failure handling, and rejects known nontransactional commands. PGlite tests pass rollback, ledger failure, unknown history, duplicate ID, and drift cases. All six GitHub Actions files remain deleted at the user's request; native migration bootstrap and permissions must still be verified on PostgreSQL 16.                                                                                                 |
| AUD-13  | Hardened Docker/Compose configuration is implemented but not container-validated.                                                                                                                                                            | Code commit `e8b7dd5` adds `.dockerignore`, a non-root two-stage image, resource/log limits, health endpoint/check, persistent uploads/PG volume, loopback DB publishing, external NPM proxy network, and internal DB network. Compose YAML parses successfully. Docker is not installed here; actual Compose validation, PG16 init, ARM64 image build, and Pi resource tests remain open.                                                                                                                                                                                                                                                   |
| AUD-15  | Pure PostgreSQL code path and schema-only baseline are implemented in the current tree; target-database and data-cutover validation remain open.                                                                                             | Code commit `e8b7dd5` removes the SDK, all 139 hosted migration files and hosted SQL apply files, historical account-specific migration replay scripts/tests, and obsolete seed tooling. It adds `db/migrations/20261020000000_native_initial.sql`; PGlite verifies 34 public relations, `security_invoker` on `question_bank`, and zero seeded profiles. Native `pg` scripts/tests, role setup, and the baseline replace the old chain. Migration/class-record/auth-rate tests, typecheck, and build pass. No PG16/Pi validation or private data import was performed.                                                                      |
| AUD-06  | Fixed and tested. `.limit(n)` is applied as a bounded SQL `LIMIT`; single-row behavior is explicit, and projections are identifier-validated.                                                                                                | Code commit `9416d72`. Query-layer tests cover 0, 1, N, invalid bounds, offset pagination, parameterized filters, invalid projections, and multiple-row results. Full unit suite passed.                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| AUD-07  | Fixed and tested. Session revocation now propagates PostgreSQL failures; logout reports durable-revocation failure after clearing its cookie.                                                                                                | Code commit `9416d72`. A simulated connection-loss test verifies the SQLSTATE is propagated; full unit suite and typecheck passed. End-to-end role/password change verification remains part of native PG testing.                                                                                                                                                                                                                                                                                                                                                                                                                           |
| AUD-08  | Path-containment remediation is implemented and regression-tested.                                                                                                                                                                           | Code commit `9416d72`. Tests cover traversal, sibling-prefix escape, absolute paths, partial-delete prevention, and symlinks. The symlink case is skipped on this Windows host and must run on Linux CI/ARM64.                                                                                                                                                                                                                                                                                                                                                                                                                               |
| AUD-09  | Mitigation applied: protected material responses now use `Cache-Control: private, no-store`.                                                                                                                                                 | Code commit `9416d72`. Browser/service-worker account-switch reproduction remains unrun, so the original hypothesis stays open pending browser evidence.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| AUD-10  | Fixed in code and pushed; live proxy and edge-limit checks remain.                                                                                                                                                                           | Commit `f9d5d9f` uses validated NPM `X-Real-IP` and ignores `X-Forwarded-For`; the limiter expires entries and caps its map at 2,048 clients. The hardware attendance endpoint caps streamed JSON at 8 KiB before parsing. The helper and limiter tests pass (23 tests, 41 assertions), as do typecheck, scoped ESLint, and `git diff --check`. NPM's upstream config sets `X-Real-IP` to `$remote_addr` ([source](https://github.com/NginxProxyManager/nginx-proxy-manager/blob/develop/docker/rootfs/etc/nginx/conf.d/include/proxy.conf)); verify actual NPM configuration, edge body limits, and kiosk traffic on the Pi before release. |
| AUD-12  | GitHub Actions CI, PR review, scheduled security smoke, and one-off material jobs remain removed at the user's request; target decision is resolved as Orange Pi + NPM.                                                                      | Commit `cf2f561` deletes all six workflow files. No replacement hosted CI is authorized; local pre-release checks and post-release smoke remain required. The repository-wide lint scan reported 212 formatting errors and 27 warnings; scoped lint without the Prettier rule and formatting checks on touched files passed.                                                                                                                                                                                                                                                                                                                 |

## 1. Recommended architecture and deployment

Run the Bun LMS application, PostgreSQL 16, and persistent local upload storage using Docker Compose on the Orange Pi Zero 3 4GB. Route `https://akios.site` through Nginx Proxy Manager (NPM). Build and verify an ARM64 application image on a development machine or CI, then deploy the versioned image to the Pi.

```text
Internet -> router TCP 80/443 -> Nginx Proxy Manager
                                  | private proxy network, HTTP :3000
                                  v
                              LMS application
                                  | private DB network, PostgreSQL :5432
                                  ` persistent local uploads
```

**Pure PostgreSQL requirement:** PostgreSQL is the only runtime database and source of truth. Remove Supabase SDK, Auth/Storage services, backend selection, SQL compatibility shims, secrets, and hosted migration workflow dependencies. Keep the LMS's custom signed-session and bcrypt/PIN authentication, with its state in PostgreSQL. Uploaded files live on persistent Pi storage. If data must be retained from an existing hosted PostgreSQL installation, use it only as a controlled one-time export source; the deployed LMS must not connect to or sync with it.

The recommended topology assumes NPM runs on the Pi. If NPM already runs on another LAN device, reuse it and follow section 7B. Capacity is unknown until representative concurrent logins, quiz submissions, and uploads are measured.

### Existing repository support and rewrite

Code commit `e8b7dd5` now supplies the native PostgreSQL starting point: the server uses `pg` and local filesystem uploads; the SDK, backend switching, hosted migration directory, and hosted apply scripts have been removed from the current tree. A schema-only native baseline, checksummed migration runner, migration-owner/app-role setup, first-admin bootstrap, Dockerfile, Compose services, `.dockerignore`, and database health endpoint are present. PGlite integration verifies the migration and role behavior. These changes have not yet been run on PostgreSQL 16, Docker, Linux ARM64, the Orange Pi, or Nginx Proxy Manager; section 11 remains the release validation gate.

## 2. Repository and baseline used for this plan

This workspace contains the repository at `eb370ea2b5f1724ffe90e5f58bcc1b9cff06b8b2`, on branch `codex/orange-pi-local-postgres`. Audit results and limitations are in section 0.13. The initial branch delivered the plan; implementation progress is recorded in section 0.14.

For implementation, re-check the intended upstream revision and repository instructions, preserve subsequent work, and use a current branch. Install with the committed lockfile, then run typecheck, lint, unit, integration, browser, database migration, and production build checks. Use disposable PostgreSQL 16. Do not treat baseline results as current if source has changed; review changed code, callers, migrations, generated output, and release artifacts again after fixes.

## 3. Convert the database layer to native PostgreSQL

This is a conversion, not simply enabling the current local fallback. The end state has one PostgreSQL connection path, one migration system, one authorization model, and filesystem uploads. The runtime has no Supabase SDK, URLs, keys, auth/storage calls, schema shims, provider selection, or hosted migration job.

1. Start PostgreSQL 16 in a disposable Linux/Docker environment with separate migration-owner and application-runtime roles.
2. Inventory all current SQL migrations and DB client/RPC usages. Generate a native PG baseline and forward-only migration chain with unique IDs. Resolve duplicate timestamp prefixes and redact/remove identity-specific data or historical account operations.
3. Convert dependencies on hosted auth/storage schemas, role names, functions, grants, and policies. Choose one explicit permissions design: enforce row ownership in server repositories with tight PG grants, or implement native RLS using transaction-local identity bound safely for every pooled transaction. Do not use a dummy `auth.uid()` function or assume an application session automatically informs RLS.
4. Replace the Supabase-shaped query adapter with parameterized `pg` queries and typed repositories. Audit all call sites and retain only needed operations; correct bounds, error propagation, transactions, and result shapes.
5. Implement a native migration ledger with full unique IDs, advisory locking, atomic SQL/ledger writes where supported, clear nontransactional handling, duplicate preflight, and failure-safe retry behavior.
6. Separate schema/migration owner credentials from the non-superuser runtime role. Verify the app cannot create roles, databases, extensions, or schema objects it does not own.
7. Exercise empty install, repeat migration, interrupted migration, concurrent migration attempts, backup and restore, and permission failures on real PostgreSQL 16.
8. Test admin, teacher, and student workflows, including denied cross-student access to grades, submissions, and private files. Test session creation/revocation and rate limits using the native PG implementation.

### Fresh installation and optional one-time data transfer

| Starting point                                       | Implementation path                                                                                                                                                                                                                                                                                                                                                                                              |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fresh installation (preferred)                       | Create a clean PostgreSQL database, apply the native migration chain, and provision an initial administrator with a one-time private bootstrap command. Use only synthetic/test data until privacy and security blockers are closed.                                                                                                                                                                             |
| Existing hosted database whose data must be retained | Treat it solely as an export source. Take a private backup, export tables and storage files once, transform schema/IDs/file metadata into the native target, and reconcile migration history without replaying hosted history. Verify row counts, constraints, representative values and file checksums; freeze writes for final transfer. Remove source credentials and prove the app no longer connects to it. |

The hosted database may be PostgreSQL, but its managed roles, schemas, extensions, policies, and file storage are not equivalent to a self-managed PostgreSQL installation. Import only application data and explicitly approved schema objects. Never expose an export containing student data in this public repository or in CI logs.

## 4. Prepare the Orange Pi and production containers

Confirm the existing OS, kernel, disk layout, free space, cooling, power supply, and other workloads. Use a maintained board-compatible server image with 64-bit userspace; verify `uname -m` is `aarch64`. Use reliable persistent storage. A USB SSD is preferable for sustained database writes; otherwise use an endurance-rated microSD and keep backups elsewhere. Do not reformat an existing server unattended.

Planned implementation:

- Add production Compose for `app` and `postgres`; attach NPM only to the proxy network. Keep PostgreSQL off the proxy network and unpublished.
- Build tested `linux/arm64` app images from pinned compatible base tags; set `NODE_ENV=production`; run the app non-root.
- Add `.dockerignore` for `.env*`, uploads, backups, Git metadata, node_modules, local DBs, documents, and build output. Inspect image layers for records/secrets.
- Add a native PostgreSQL migration job/image using a migration-owner credential. Run it once before rollout; runtime app credentials must not own the schema or run migrations.
- Start app after DB health and migration success. Persist PG, LMS uploads, NPM config, and certificates with documented ownership and recovery.
- Add health/readiness checks, restart policy, bounded logs, resource limits, release/rollback steps, and confirm the server binds port 3000 on the container network.

Bun images and Docker support ARM64; verify exact tags and dependencies during implementation. References: [Bun installation](https://bun.sh/docs/installation), [Docker Engine on Debian](https://docs.docker.com/engine/install/debian/).

### Initial resource targets

| Component     | Starting point                                                             |
| ------------- | -------------------------------------------------------------------------- |
| LMS           | One process; `PG_POOL_MAX=5`; roughly 1 GB memory limit                    |
| PostgreSQL    | Roughly 1 GB; `shared_buffers=256MB`, `work_mem=4MB`, `max_connections=30` |
| NPM           | Default SQLite configuration initially; measure alongside LMS              |
| Remaining RAM | Linux, filesystem cache, Docker overhead, and spikes                       |

These are proposals, not measured requirements. PostgreSQL memory also depends on concurrent operations. Tune after Pi load tests. See [PostgreSQL resource settings](https://www.postgresql.org/docs/16/runtime-config-resource.html).

## 5. Application configuration

Create a production environment example; generate actual secrets only on the server:

```dotenv
NODE_ENV=production
DATABASE_URL=postgres://miow_app:REPLACE_WITH_URL_ENCODED_PASSWORD@postgres:5432/miow
PG_POOL_MAX=5
STORAGE_PATH=/app/storage
SESSION_SECRET=REPLACE_WITH_A_RANDOM_SECRET
SITE_URL=https://akios.site
```

Generate the session secret with a command such as `openssl rand -hex 32`. Use separate runtime and migration passwords. Never commit actual environment files or pass private credentials as Vite build arguments. Remove all `SUPABASE_*` runtime settings and reads; stale variables must not select an alternate backend. Fail startup on invalid required DB/session settings.

AI and Google integrations remain optional and independent of database choice. If Google integration is used, register `https://akios.site` and verify callback URLs. External AI/Google/assets may need internet even though DB and files are local.

## 6. Network prerequisites for akios.site

Direct publishing requires authoritative DNS control, router access, and an inbound-reachable connection. Current DNS provider, records, and ISP connectivity have not been inspected.

1. Reserve a LAN address for the Pi in DHCP (example only: `192.168.1.50`).
2. Compare router WAN IPv4 with the public address seen from that connection, without VPN/proxy.
3. Investigate CGNAT/double NAT if they differ. Private WAN ranges (`10/8`, `172.16/12`, `192.168/16`) and shared `100.64/10` indicate likely obstacles; a public-looking address does not prove ports are open.
4. Configure upstream forwarding or request a public IPv4 from the ISP; use section 10 if CGNAT remains.
5. Check whether inbound TCP 80/443 is allowed and identify any existing service using them.

If the address changes, use dynamic DNS for the domain A record and store a zone-scoped DNS API credential outside the repository.

## 7. Set up Nginx Proxy Manager

### 7A. NPM and LMS on the same Pi (recommended)

Use a shared proxy network for NPM and the application, and a separate network between app and PostgreSQL. Keep PostgreSQL off the proxy network. Create the shared network once:

```sh
docker network create miow-proxy
```

If it already exists, reuse it. NPM can use its default SQLite configuration. This example is a proposed stack; revalidate the image version before deployment. References: [NPM setup](https://nginxproxymanager.com/setup/) and [NPM shared Docker network guidance](https://nginxproxymanager.com/advanced-config/).

```yaml
services:
  npm:
    image: jc21/nginx-proxy-manager:2.16.0
    restart: unless-stopped
    environment:
      TZ: Asia/Singapore
    ports:
      - "80:80"
      - "443:443"
      - "127.0.0.1:81:81"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    networks: [proxy]
networks:
  proxy:
    external: true
    name: miow-proxy
```

Attach the app to this network with alias `miow-lms-app` and its own DB network. In this topology the app and database need no host port mapping. From the NPM directory run `docker compose up -d`. The admin port is loopback only; access it remotely through an SSH tunnel:

```sh
ssh -N -L 8181:127.0.0.1:81 YOUR_PI_USER@192.168.1.50
```

Then visit `http://127.0.0.1:8181`, configure a strong NPM admin password, and never forward port 81 through the router.

### 7B. NPM on another LAN device

Forward public 80/443 to that NPM host. Publish the LMS port only on the Pi's LAN address, e.g. `192.168.1.50:3000:3000`, and configure NPM upstream `http://192.168.1.50:3000`. Restrict that port to NPM using rules effective for Docker-published traffic and verify from another LAN device. Keep PostgreSQL private and NPM admin LAN/VPN/SSH-only. Do not use `127.0.0.1` as an upstream from inside the NPM container.

## 8. Point akios.site to the server

At the authoritative DNS provider, review existing records first; changing the apex directs the root domain to the LMS. Preserve unrelated MX/TXT records.

| Type  | Name  | Value              | Purpose              |
| ----- | ----- | ------------------ | -------------------- |
| A     | `@`   | Actual public IPv4 | Serve `akios.site`   |
| CNAME | `www` | `akios.site`       | Optional `www` alias |

Do not publish AAAA until IPv6, firewall, and NPM route work; correct stale AAAA records. If Cloudflare is authoritative, initially use DNS-only while testing; provider is not assumed. See [Cloudflare DNS records](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/).

Check from a client:

```sh
nslookup -type=A akios.site 1.1.1.1
nslookup -type=AAAA akios.site 1.1.1.1
```

For direct IPv4 routing, forward TCP 80 and 443 to the NPM host's reserved LAN IP and permit them through relevant firewalls. Never forward ports 3000, 5432, or 81 to the internet. See the [NPM guide](https://nginxproxymanager.com/guide/).

## 9. Add the NPM proxy host and HTTPS certificate

After the app is healthy and reachable from NPM, create a proxy host:

| Field                 | Value                                                        |
| --------------------- | ------------------------------------------------------------ |
| Domain Names          | `akios.site`                                                 |
| Scheme                | `http`                                                       |
| Forward Hostname / IP | `miow-lms-app` on shared Docker network; otherwise Pi LAN IP |
| Forward Port          | `3000`                                                       |
| Cache Assets          | Off initially                                                |
| Websockets Support    | On                                                           |
| Access List           | Public; LMS enforces login                                   |

Test `http://akios.site/auth` from outside the LAN (e.g. mobile data). In SSL settings request a Let's Encrypt certificate for `akios.site`, accept terms, enable Force SSL and HTTP/2 if available. HTTP-01 requires public port 80; DNS-01 can issue without HTTP ingress but does not make an unreachable site accessible. See [Let's Encrypt challenge types](https://letsencrypt.org/docs/challenge-types/). Keep HSTS off initially and enable subdomain coverage only after all subdomains are verified; see AUD-17. Add `www` only if DNS and certificate coverage are configured, then redirect it to the apex.

Behind NPM, verify canonical URL, forwarded host/protocol, secure session cookies, trusted proxy/client-IP handling, streaming/WebSocket behavior, upload limits, and renewal. Do not cache authenticated HTML/API responses. Test PWA account switching. Back up NPM data and certificate files.

From outside the LAN:

```sh
curl -I http://akios.site/auth
curl -I https://akios.site/auth
```

HTTP should redirect to HTTPS; HTTPS should present a trusted certificate and reach the LMS. Also test browser login and uploads.

| Symptom                        | First checks                                                         |
| ------------------------------ | -------------------------------------------------------------------- |
| Timeout                        | DNS, CGNAT/public connectivity, port forwarding, firewall, listeners |
| NPM default page               | Proxy-host domain and intended NPM instance                          |
| 502                            | App health/listening interface, upstream, Docker networks, LAN route |
| Certificate failure            | Port 80 for HTTP-01, A/AAAA, CAA, conflicts, NPM logs                |
| Redirect/cookie issue          | Canonical URL, forwarded protocol, proxy trust, cookie flags         |
| Upload 413                     | Nginx and app upload limits                                          |
| Mobile works, home Wi-Fi fails | NAT loopback; consider split DNS to NPM LAN IP                       |

## 10. If CGNAT prevents direct publishing

1. Ask ISP for a public IPv4 and use sections 6-9.
2. Use a public VPS gateway with a private tunnel back to NPM; route only website traffic over that tunnel.
3. If using Cloudflare DNS, evaluate Cloudflare Tunnel as an outbound connection to NPM's private listener with the correct host/TLS handling. This is an alternative connectivity design, not deployed by this plan. See [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/).

## 11. Validation, backup, and recovery

Before public use:

- Resolve the Critical and High findings in section 0.13 and attach test/commit evidence. Confirm the release tree, image, and public docs contain no real student/account records or demo credentials.
- Pass typecheck, lint, unit, integration, production build, and browser checks. Run database integration and migration tests on real PostgreSQL 16 with the exact native migration chain and least-privilege roles; assert no Supabase SDK/config/schema/service is required.
- Verify login/logout, session revocation, role/permission boundaries, attendance, courses, timed quizzes, submission persistence, grading, uploads, and downloads. Include cross-student denial, stale credentials, private attachment caching, shared-browser account switching, oversized input, error/retry, path traversal, and spoofed proxy-header cases from section 0.13.
- Reboot the Pi and confirm services restart and records/files persist. Verify image architecture and measured capacity under realistic concurrency while measuring latency, CPU temperature, RAM, DB connections, storage latency, and disk space.
- Confirm only intended public ports are reachable and NPM administration remains private. Ensure PostgreSQL is inaccessible from WAN and the proxy network.
- Check the actual external HTTPS certificate and application behavior at `https://akios.site`, including cookies, headers, upload limits, streaming, redirects, and proxy trust.
- Provision a non-default first administrator; confirm no demonstration or shared credential remains active before real school data is loaded.

Schedule native PostgreSQL dumps and upload backups to a second device or off-server destination. Back up NPM configuration/certificates and protect required environment secrets separately. Coordinate database and file backups so restored file references remain valid. Define retention and monitor backup failures.

Perform a restore into a clean environment and verify representative records, authorization boundaries, and attachments. Document application-image rollback separately from database recovery: a migration may make an older application image incompatible. Do not use `docker compose down -v` as a production restart or update command.

For an existing installation, take a final private backup and freeze writes during the one-time export/import. Keep the former deployment recoverable until the native PostgreSQL host passes validation, then revoke old source credentials and remove temporary exports according to the approved retention policy. Document how to restore routing and data if cutover fails.

## 12. Commit and push this plan

This plan and audit record are maintained on `codex/orange-pi-local-postgres`. Code commit `e8b7dd5` and the earlier remediation commits are pushed to the branch. The code changes do not merge to `main`, deploy the app, alter DNS, or modify a running server.

Remaining implementation and deployment gates are:

- Inspect and test the Compose role bootstrap on PostgreSQL 16; build/test the image for Linux ARM64 and measure it on the Orange Pi.
- The user confirmed Orange Pi + NPM as the target. Verify the Pi/NPM host details and actual DNS/router state before changing DNS or performing cutover.
- Review and, if approved, migrate any existing private data and files using a one-time export/import; no production records were included in the baseline.
- Complete the privacy-history review/remediation, browser and application regression checks, proxy/domain setup, public-network checks, backups, restore, and resource/load testing in section 0.13 and section 11.

Do not publish or cut over to public use until Critical/High findings and the host-specific release gates are closed.

## 13. Inputs to confirm during implementation

- Pi OS/version, architecture, storage capacity/type, cooling, and other running services.
- Whether NPM already exists and which machine hosts it.
- Router model, public IPv4/CGNAT status, ISP port restrictions, and dynamic IP behavior.
- Authoritative DNS provider for `akios.site`, existing apex usage, and whether `www` is wanted.
- Fresh PostgreSQL install versus private one-time export/import of hosted data/files, only if retention is required.
- Expected simultaneous users, assessment load, maximum upload sizes, and backup destination.
- Server access and image build/distribution method.
