import { afterAll, beforeAll, expect, test } from "bun:test";
import { PGlite } from "@electric-sql/pglite";
import { readFile } from "node:fs/promises";

const db = new PGlite();
const approval = await readFile(
  "supabase/migrations/20261019000006_approve_tau_it10_retake_requests.sql",
  "utf8",
);
const recovery = await readFile(
  "supabase/migrations/20261019000011_grant_billy_mapula_force_submit_retake.sql",
  "utf8",
);
beforeAll(async () => {
  await db.exec(`
    CREATE TABLE profiles(id uuid PRIMARY KEY, student_id text, email text, role text, deleted_at timestamptz);
    CREATE TABLE courses(id uuid PRIMARY KEY, code text);
    CREATE TABLE quizzes(id uuid PRIMARY KEY, course_id uuid, title text, deleted_at timestamptz);
    CREATE TABLE quiz_retake_requests(student_id uuid, quiz_id uuid, status text);
    CREATE TABLE quiz_attempts(id uuid, student_id uuid, quiz_id uuid, tab_switches jsonb, created_at timestamptz, attempt_number integer);
    INSERT INTO profiles VALUES ('00000000-0000-4000-8000-000000000001','2026-0112','billyjohnwel.mapula@g.msuiit.edu.ph','student',NULL);
  `);
});
afterAll(() => db.close());
test("historical approvals and recovery skip absent live requests or attempts", async () => {
  await db.exec(approval);
  await db.exec(recovery);
  expect((await db.query("SELECT * FROM quiz_retake_requests")).rows).toHaveLength(0);
});
test("historical approval still refuses ambiguous worksheet requests", async () => {
  await db.exec(`
    INSERT INTO profiles VALUES ('00000000-0000-4000-8000-000000000002','2026-0099','qa@example.test','student',NULL);
    INSERT INTO courses VALUES ('00000000-0000-4000-8000-000000000003','IT10');
    INSERT INTO quizzes SELECT id,'00000000-0000-4000-8000-000000000003','Quiz',NULL FROM (VALUES ('00000000-0000-4000-8000-000000000004'::uuid),('00000000-0000-4000-8000-000000000005'::uuid)) t(id);
    INSERT INTO quiz_retake_requests SELECT '00000000-0000-4000-8000-000000000002',id,'pending' FROM quizzes;
  `);
  await expect(db.exec(approval)).rejects.toThrow("found 2 distinct worksheets");
  expect(
    (await db.query("SELECT * FROM quiz_retake_requests WHERE status='pending'")).rows,
  ).toHaveLength(2);
});
