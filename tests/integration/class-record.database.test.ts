import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { PGlite } from "@electric-sql/pglite";
import { readFile } from "node:fs/promises";
const db = new PGlite();
const course = crypto.randomUUID(),
  other = crypto.randomUUID(),
  actor = crypto.randomUUID(),
  student = crypto.randomUUID(),
  quiz = crypto.randomUUID(),
  attempt = crypto.randomUUID(),
  question = crypto.randomUUID();
beforeAll(async () => {
  await db.exec(
    `CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role; CREATE TABLE profiles(id uuid PRIMARY KEY); CREATE TABLE courses(id uuid PRIMARY KEY,code text); CREATE TABLE grades(student_id uuid REFERENCES profiles(id),course_id uuid,quarter integer,written_work_score numeric,performance_task_score numeric,exam_score numeric,transmuted_final_grade numeric,UNIQUE(student_id,course_id,quarter)); CREATE TABLE quizzes(id uuid PRIMARY KEY,course_id uuid,retake_score_policy text); CREATE TABLE feedback_reports(id uuid PRIMARY KEY,reporter_id uuid); CREATE TABLE quiz_retake_grants(quiz_id uuid,student_id uuid,extra_attempts integer,UNIQUE(quiz_id,student_id)); CREATE TABLE quiz_attempts(id uuid PRIMARY KEY,results jsonb,raw_score integer,integrity_penalty integer,score integer,total integer);`,
  );
  await db.exec(await readFile("supabase/migrations/20261019140001_class_records.sql", "utf8"));
  await db.exec(await readFile("supabase/migrations/20261019140002_question_reviews.sql", "utf8"));
  await db.exec(
    await readFile("supabase/migrations/20261019140004_report_recovery_grants.sql", "utf8"),
  );
  await db.query("INSERT INTO profiles VALUES ($1),($2)", [actor, student]);
  await db.query("INSERT INTO courses VALUES ($1,'IT10'),($2,'OTHER')", [course, other]);
});
afterAll(() => db.close());
function save(revision: number, publications: unknown[] = []) {
  return db.query("SELECT save_class_record($1::uuid,1,$2::integer,$3::jsonb,$4::uuid,$5::jsonb)", [
    course,
    revision,
    JSON.stringify({ columns: [] }),
    actor,
    JSON.stringify(publications),
  ]);
}
describe("atomic draft/publication migration", () => {
  it("saves drafts without publishing and rejects stale revisions", async () => {
    await save(0);
    expect((await db.query("SELECT * FROM grades")).rows).toHaveLength(0);
    await expect(save(0)).rejects.toThrow("changed in another window");
  });
  it("rolls back the entire save when any selected publication fails", async () => {
    const snapshot = { ww: 100, pt: 100, ex: 100, scale: "college", final: 1 };
    await expect(
      save(1, [
        { student_id: student, snapshot },
        { student_id: crypto.randomUUID(), snapshot },
      ]),
    ).rejects.toThrow();
    expect(
      (await db.query<{ revision: number }>("SELECT revision FROM class_records")).rows[0]!
        .revision,
    ).toBe(1);
    expect((await db.query("SELECT * FROM grades")).rows).toHaveLength(0);
  });
  it("publishes decimal college grades in the snapshot without a DepEd value", async () => {
    await save(1, [
      { student_id: student, snapshot: { ww: 85, pt: 90, ex: 88, scale: "college", final: 1.5 } },
    ]);
    const row = (
      await db.query<{
        class_record_snapshot: { final: number };
        transmuted_final_grade: number | null;
      }>("SELECT * FROM grades")
    ).rows[0]!;
    expect(row.class_record_snapshot.final).toBe(1.5);
    expect(row.transmuted_final_grade).toBe(null);
  });
  it("enforces IT10 highest-score policy without changing other courses", async () => {
    await db.query("INSERT INTO quizzes VALUES ($1,$2,'latest_attempt'),($3,$4,'average_score')", [
      quiz,
      course,
      crypto.randomUUID(),
      other,
    ]);
    await db.query("UPDATE quizzes SET retake_score_policy='average_score' WHERE id=$1", [quiz]);
    const rows = (
      await db.query<{ course_id: string; retake_score_policy: string }>("SELECT * FROM quizzes")
    ).rows;
    expect(rows.find((r) => r.course_id === course)!.retake_score_policy).toBe("highest_score");
    expect(rows.find((r) => r.course_id === other)!.retake_score_policy).toBe("average_score");
  });
  it("reviews exactly one question, preserves responses/penalties and records an audit", async () => {
    const results = [
      { id: question, chosen: "the third gives the multiplier", correct: false },
      { id: crypto.randomUUID(), chosen: "another answer", correct: true },
    ];
    await db.query("INSERT INTO quiz_attempts VALUES ($1,$2::jsonb,1,1,0,2)", [
      attempt,
      JSON.stringify(results),
    ]);
    await db.query(
      "SELECT review_attempt_question($1::uuid,$2::uuid,true,false,'Verified rubric explanation',$3::uuid)",
      [attempt, question, actor],
    );
    const row = (
      await db.query<{
        score: number;
        raw_score: number;
        integrity_penalty: number;
        results: typeof results;
      }>("SELECT * FROM quiz_attempts")
    ).rows[0]!;
    expect(row.raw_score).toBe(2);
    expect(row.score).toBe(1);
    expect(row.integrity_penalty).toBe(1);
    expect(row.results[0]!.chosen).toBe(results[0]!.chosen);
    expect((await db.query("SELECT * FROM quiz_question_reviews")).rows).toHaveLength(1);
    await expect(
      db.query(
        "SELECT review_attempt_question($1::uuid,$2::uuid,true,false,'duplicate',$3::uuid)",
        [attempt, question, actor],
      ),
    ).rejects.toThrow("already reviewed");
  });
  it("grants one recovery attempt exactly once per report, including retries", async () => {
    const report = crypto.randomUUID();
    await db.query("INSERT INTO feedback_reports VALUES ($1,$2)", [report, student]);
    await db.query("SELECT grant_report_recovery($1::uuid,$2::uuid,$3::uuid)", [
      report,
      quiz,
      student,
    ]);
    await db.query("SELECT grant_report_recovery($1::uuid,$2::uuid,$3::uuid)", [
      report,
      quiz,
      student,
    ]);
    const grant = (await db.query<{ extra_attempts: number }>("SELECT * FROM quiz_retake_grants"))
      .rows[0]!;
    expect(grant.extra_attempts).toBe(1);
    expect((await db.query("SELECT * FROM feedback_recovery_grants")).rows).toHaveLength(1);
  });
  it("exposes neither draft data nor repair RPCs to anonymous clients", async () => {
    await db.exec("SET ROLE anon");
    await expect(db.query("SELECT * FROM class_records")).rejects.toThrow();
    await expect(save(2)).rejects.toThrow();
    await db.exec("RESET ROLE");
  });
});
