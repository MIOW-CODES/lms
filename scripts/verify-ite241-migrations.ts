import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Pool } from "pg";

// Exercise the existing-course migration path in CI without changing its fixtures.
const url = process.env.DATABASE_URL;
if (!url || !["localhost", "127.0.0.1"].includes(new URL(url).hostname)) {
  throw new Error("ITE241 migration verification requires an isolated localhost database");
}
const pool = new Pool({ connectionString: url });
const client = await pool.connect();
try {
  await client.query("BEGIN");
  await client.query(
    "INSERT INTO public.courses (code, title, grade_level) VALUES ('ITE241', 'ITE241-Advanced Digital Electronics', 13)",
  );
  const files = [
    "20261016000003_seed_ite241_assessments.sql",
    "20261016000004_enroll_ite241_cohort.sql",
    "20261016000005_correct_ite241_maed_tvle_cohort.sql",
  ];
  // Repeating the migrations also checks that they preserve the seeded bank.
  for (let pass = 0; pass < 2; pass++) {
    for (const file of files) {
      await client.query(
        await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), "utf8"),
      );
    }
  }
  const { rows: assessments } = await client.query(
    `SELECT q.title, q.duration_minutes, q.question_count,
            count(qq.id)::int AS bank_size,
            count(qq.id) FILTER (WHERE jsonb_array_length(qq.options) > 0)::int AS multiple_choice
       FROM public.quizzes q
       JOIN public.courses c ON c.id = q.course_id
       LEFT JOIN public.quiz_questions qq ON qq.quiz_id = q.id
      WHERE c.code = 'ITE241' AND q.deleted_at IS NULL
      GROUP BY q.id ORDER BY q.title`,
  );
  assert.equal(assessments.length, 5);
  for (const assessment of assessments) {
    const exam = assessment.title === "1st Quarter Exam";
    const essay = assessment.title.startsWith("Essay Assessment");
    assert.equal(assessment.duration_minutes, exam ? 60 : 10);
    assert.equal(assessment.question_count, exam ? 50 : essay ? 2 : 20);
    assert.ok(assessment.bank_size >= assessment.question_count, assessment.title);
    if (exam) {
      assert.equal(assessment.bank_size, 50);
      assert.equal(assessment.multiple_choice, 50);
    }
    if (essay) assert.equal(assessment.bank_size, 2);
  }
  const {
    rows: [course],
  } = await client.query(
    `SELECT c.college_year, s.name AS section, c.program,
            (SELECT count(*)::int FROM public.enrollments e WHERE e.course_id = c.id) AS enrolled,
            (SELECT jsonb_array_length(t.items) FROM public.tos t WHERE t.course_id = c.id AND t.quarter = 1) AS tos_items
       FROM public.courses c JOIN public.sections s ON s.id = c.section_id WHERE c.code = 'ITE241'`,
  );
  assert.equal(course.college_year, null);
  assert.equal(course.section, "241");
  assert.ok(course.program.includes("Master of Arts in Education"));
  assert.equal(course.enrolled, 14);
  assert.equal(course.tos_items, 5);

  const {
    rows: [ict1],
  } = await client.query(
    `INSERT INTO public.courses (code, title, grade_level)
     VALUES ('ICT1', 'ICT1 migration fixture', 13)
     RETURNING id`,
  );
  const {
    rows: [finalExam],
  } = await client.query(
    `INSERT INTO public.quizzes (course_id, title, closes_at)
     VALUES ($1, 'ICT1 Final Exam', now() + interval '1 hour')
     RETURNING id`,
    [ict1.id],
  );
  await client.query(
    await readFile(
      new URL(
        "../supabase/migrations/20261020021400_close_ict1_final_exam_now.sql",
        import.meta.url,
      ),
      "utf8",
    ),
  );
  const {
    rows: [closedExam],
  } = await client.query("SELECT closes_at FROM public.quizzes WHERE id = $1", [finalExam.id]);
  assert.ok(new Date(closedExam.closes_at).getTime() < Date.now());

  console.log(
    "Data migrations verified: ITE241 assessments and cohort, repeat-safe, ICT1 final close",
  );
} finally {
  await client.query("ROLLBACK");
  client.release();
  await pool.end();
}
