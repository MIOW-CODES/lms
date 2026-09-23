/* eslint-disable @typescript-eslint/no-explicit-any */
// Quizzes — CRUD, attempts, retake policy engine, essay grading, scoring.
import { z } from "zod";
import { db } from "@/integrations/db/client.server";
import { unwrap, withoutToken } from "@/lib/server/utils.server";
import { requireSession, requireStaff } from "@/lib/server/auth.server";
import { schemas } from "@/lib/server/schemas.server";
import type { IntegrityEventType } from "@/lib/integrity";

export async function listQuizzes() {
  return unwrap<any[]>(db.from("quizzes").select("*").is("deleted_at", null));
}

/** In-place Fisher-Yates shuffle (uniform random permutation). */
function shuffleInPlace<T>(arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j]!, arr[i]!];
  }
  return arr;
}

/**
 * Question-bank selection. Chooses `count` questions out of `all`, preferring
 * questions the student has NOT seen in prior attempts (so retakes surface fresh
 * items), then filling any remainder from the previously-seen pool when the bank
 * is exhausted. Both pools are shuffled so the presentation order also varies.
 *
 * Pure and exported for unit testing.
 */
export function selectQuestionBank<T extends { id: string }>(
  all: T[],
  count: number,
  usedIds: Iterable<string>,
): T[] {
  if (count <= 0 || all.length <= count) return all;
  const used = new Set(usedIds);
  const unused: T[] = [];
  const seen: T[] = [];
  for (const q of all) (used.has(q.id) ? seen : unused).push(q);
  shuffleInPlace(unused);
  shuffleInPlace(seen);
  return [...unused, ...seen].slice(0, count);
}

export async function getQuizPublic(id: string, studentId?: string) {
  const quiz = await unwrap<any>(
    db.from("quizzes").select("*").eq("id", id).is("deleted_at", null).single(),
  );
  let questions = await unwrap<any[]>(
    db
      .from("quiz_questions")
      .select("id, quiz_id, question, options, position")
      .eq("quiz_id", id)
      .order("position"),
  );
  // Question bank: if question_count > 0, take a random subset that avoids
  // questions this student already answered in prior attempts when possible.
  const questionCount = quiz.question_count ?? 0;
  if (questionCount > 0 && questions.length > questionCount) {
    let usedIds: string[] = [];
    if (studentId) {
      // A single indexed query for THIS student's prior attempts — not N+1.
      // Covered by idx_quiz_attempts_quiz_student (quiz_id, student_id).
      const prior = await unwrap<Array<{ question_ids: string[] | null }>>(
        db
          .from("quiz_attempts")
          .select("question_ids")
          .eq("quiz_id", id)
          .eq("student_id", studentId),
      );
      usedIds = prior.flatMap((a) => (Array.isArray(a.question_ids) ? a.question_ids : []));
    }
    const selected = selectQuestionBank(questions, questionCount, usedIds);
    // Randomize presentation order, then re-number positions.
    questions = shuffleInPlace([...selected]).map((q, i) => ({ ...q, position: i + 1 }));
  }
  return { quiz, questions };
}

/* ---------- Essay auto-grading (strict) ---------- */

const ESSAY_MIN_WORDS = 5;

function essayWords(answer: string): string[] {
  return answer.toLowerCase().match(/[a-z][a-z'-]*/g) ?? [];
}

function isGibberishAnswer(answer: string, words: string[]): boolean {
  if (words.length < ESSAY_MIN_WORDS) return true;
  const lower = answer.toLowerCase();
  if (/([a-z])\1{3,}/.test(lower)) return true;
  if (words.some((w) => w.length >= 5 && !/[aeiou]/.test(w))) return true;
  return false;
}

export function parseKeywordCategories(rubric: string): string[][] {
  const m = rubric.match(/\|\s*keywords?\s*:\s*(.+)$/i) ?? rubric.match(/^keywords?\s*:\s*(.+)$/i);
  if (!m) return [];
  return m[1]!
    .split(";")
    .map((group) =>
      group
        .replace(/^[^=;]*=\s*/, "")
        .split(/[,/|]/)
        .map((k) => k.trim().toLowerCase())
        .filter(Boolean),
    )
    .filter((g) => g.length > 0);
}

const RUBRIC_STOPWORDS = new Set(
  (
    "the a an and or of to in on for with by is are was were be that this it its as at from their they them his her he she you your we our " +
    "not no but if then than so such into over under between about through during before after above below each other some any all both " +
    "more most less very can could should would may might must will shall do does did done pass fail requires require required full marks " +
    "credit answer answers response responses explanation identification identify coherent complete incomplete gibberish single word words " +
    "instantly elements element two one concept concepts specific technique demonstrates demonstrate shows show mention mentions"
  ).split(" "),
);

function rubricConcepts(rubric: string): string[] {
  const words = (rubric.toLowerCase().match(/[a-z][a-z-]{2,}/g) ?? []).filter(
    (w) => !RUBRIC_STOPWORDS.has(w),
  );
  return [...new Set(words)];
}

function keywordHit(answer: string, keyword: string): boolean {
  const needle = keyword.trim().toLowerCase();
  if (!needle) return false;
  if (needle.includes(" ")) return answer.toLowerCase().includes(needle);
  return new RegExp(`\\b${needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\w*`, "i").test(answer);
}

export function gradeEssay(answer: string, rubric: string): boolean {
  const words = essayWords(answer);
  if (isGibberishAnswer(answer, words)) return false;
  const categories = parseKeywordCategories(rubric);
  if (categories.length >= 2) {
    const hitCategories = categories.filter((cat) =>
      cat.some((kw) => keywordHit(answer, kw)),
    ).length;
    return hitCategories >= 2;
  }
  const concepts = categories[0] ?? rubricConcepts(rubric);
  return concepts.filter((kw) => keywordHit(answer, kw)).length >= 2;
}

/* ---------- Scoring ---------- */

async function scoreQuiz(quiz_id: string, answers: Record<string, string>, questionIds?: string[]) {
  let query = db
    .from("quiz_questions")
    .select("id, question, options, correct_answer")
    .eq("quiz_id", quiz_id)
    .order("position");
  // If question_ids provided (question bank), only score those questions
  if (questionIds && questionIds.length > 0) {
    query = query.in("id", questionIds);
  }
  const questions =
    await unwrap<Array<{ id: string; question: string; options: unknown; correct_answer: string }>>(
      query,
    );
  const norm = (s: string) =>
    s
      .trim()
      .toLowerCase()
      .replace(/\s+/g, " ")
      .replace(/[.,;:!?]+$/, "");
  const results = questions.map((q) => {
    const chosen = answers[q.id] ?? null;
    const options = (Array.isArray(q.options) ? q.options : []) as string[];
    const key = q.correct_answer as string;
    const isEssay = options.length === 0 && key.startsWith("Rubric:");
    const variants = key.split("||").map(norm);
    const correct = isEssay
      ? !!chosen && gradeEssay(chosen, key.slice("Rubric:".length).trim())
      : chosen != null && variants.includes(norm(chosen));
    return {
      id: q.id as string,
      question: q.question as string,
      options,
      chosen,
      correct_answer: key,
      correct,
    };
  });
  const score = results.filter((r) => r.correct).length;
  return { score, total: questions.length, results };
}

/* ---------- Retake policy engine ---------- */

type RetakePolicy = "highest_score" | "latest_attempt" | "average_score";

interface QuizConfig {
  id: string;
  course_id: string;
  title: string;
  allow_retake: boolean;
  max_attempts: number;
  retake_score_policy: RetakePolicy;
  score_released: boolean;
  answer_key_released: boolean;
  question_count: number;
}

const QUIZ_CONFIG_COLS =
  "id, course_id, title, allow_retake, max_attempts, retake_score_policy, score_released, answer_key_released, question_count";

async function getQuizConfig(quizId: string): Promise<QuizConfig> {
  const quiz = await unwrap<any>(
    db.from("quizzes").select(QUIZ_CONFIG_COLS).eq("id", quizId).maybeSingle(),
  );
  if (!quiz) throw new Error("Worksheet not found.");
  return quiz as QuizConfig;
}

async function attemptsFor(quizId: string, studentId: string) {
  return unwrap<
    Array<{ attempt_number: number; score: number; total: number; created_at: string }>
  >(
    db
      .from("quiz_attempts")
      .select("attempt_number, score, total, created_at")
      .eq("quiz_id", quizId)
      .eq("student_id", studentId)
      .order("attempt_number"),
  );
}

async function extraAttemptsFor(quizId: string, studentId: string): Promise<number> {
  const grant = await unwrap<any>(
    db
      .from("quiz_retake_grants")
      .select("extra_attempts")
      .eq("quiz_id", quizId)
      .eq("student_id", studentId)
      .maybeSingle(),
  );
  return typeof grant?.extra_attempts === "number" ? grant.extra_attempts : 0;
}

function attemptCeiling(quiz: QuizConfig, extra: number): number | null {
  if (quiz.allow_retake && quiz.max_attempts === 0) return null;
  const base = quiz.allow_retake ? quiz.max_attempts : 1;
  return base + extra;
}

type AttemptRow = {
  attempt_number: number;
  score: number;
  total: number;
  tab_switches?: Array<{ at: number; type: string }>;
};

function effectiveScore(
  attempts: AttemptRow[],
  policy: RetakePolicy,
): { score: number; total: number } | null {
  if (!attempts.length) return null;
  const pct = (a: AttemptRow) => (a.total > 0 ? a.score / a.total : 0);
  if (policy === "latest_attempt") {
    const latest = attempts.reduce((a, b) => (b.attempt_number > a.attempt_number ? b : a));
    return { score: latest.score, total: latest.total };
  }
  if (policy === "average_score") {
    const total = attempts[0]!.total;
    const avg = attempts.reduce((s, a) => s + pct(a), 0) / attempts.length;
    return { score: Math.round(avg * total * 100) / 100, total };
  }
  const best = attempts.reduce((a, b) => (pct(b) > pct(a) ? b : a));
  return { score: best.score, total: best.total };
}

export async function submitQuizAttempt(
  quiz_id: string,
  answers: Record<string, string>,
  token: string,
  questionIds?: string[],
  tabSwitches?: Array<{ at: number; type: IntegrityEventType }>,
) {
  const caller = await requireSession(token);
  const quiz = await getQuizConfig(quiz_id);
  const [attempts, extra] = await Promise.all([
    attemptsFor(quiz_id, caller.id),
    extraAttemptsFor(quiz_id, caller.id),
  ]);
  const ceiling = attemptCeiling(quiz, extra);
  if (ceiling != null && attempts.length >= ceiling) {
    return {
      ok: false as const,
      reason: (!quiz.allow_retake && extra === 0 ? "retakes_disabled" : "max_attempts") as
        "retakes_disabled" | "max_attempts",
      attempts_used: attempts.length,
      attempts_allowed: ceiling,
    };
  }

  // questionIds passed from client for question bank scoring
  const { score, total, results } = await scoreQuiz(quiz_id, answers, questionIds);
  const attempt_number = attempts.reduce((m, a) => Math.max(m, a.attempt_number), 0) + 1;
  await unwrap(
    db.from("quiz_attempts").insert({
      quiz_id,
      student_id: caller.id,
      attempt_number,
      score,
      total,
      results,
      question_ids: questionIds ?? [],
      tab_switches: tabSwitches ?? [],
    }),
  );

  const used = attempts.length + 1;
  const eff = effectiveScore(
    [...attempts, { attempt_number, score, total }],
    quiz.retake_score_policy,
  );
  const isScoreReleased = quiz.score_released === true;
  const isAnswerKeyReleased = quiz.answer_key_released === true;
  const gatedResults = isAnswerKeyReleased
    ? results
    : results.map((r) => ({ ...r, correct_answer: "" }));
  const gatedScore = isScoreReleased ? score : null;
  const gatedEffective = isScoreReleased ? (eff?.score ?? score) : null;
  return {
    ok: true as const,
    score: gatedScore as number | null,
    total,
    results: gatedResults,
    attempt_number,
    attempts_used: used,
    attempts_allowed: ceiling,
    can_retake: ceiling == null || used < ceiling,
    effective_score: gatedEffective as number | null,
    retake_score_policy: quiz.retake_score_policy,
    score_released: isScoreReleased,
    answer_key_released: isAnswerKeyReleased,
  };
}

export async function quizAttemptInfo(quiz_id: string, token: string) {
  const caller = await requireSession(token);
  const quiz = await getQuizConfig(quiz_id);
  const [attempts, extra] = await Promise.all([
    attemptsFor(quiz_id, caller.id),
    extraAttemptsFor(quiz_id, caller.id),
  ]);
  const ceiling = attemptCeiling(quiz, extra);
  const eff = effectiveScore(attempts, quiz.retake_score_policy);
  const isScoreReleased = quiz.score_released === true;
  return {
    quiz_id,
    allow_retake: quiz.allow_retake,
    max_attempts: quiz.max_attempts,
    retake_score_policy: quiz.retake_score_policy,
    attempts_used: attempts.length,
    attempts_allowed: ceiling,
    can_retake: attempts.length === 0 || ceiling == null || attempts.length < ceiling,
    effective_score: isScoreReleased ? (eff?.score ?? null) : null,
    effective_total: isScoreReleased ? (eff?.total ?? null) : null,
    extra_attempts: extra,
    score_released: isScoreReleased,
    answer_key_released: quiz.answer_key_released === true,
  };
}

export async function listMyQuizSummaries(token: string) {
  const caller = await requireSession(token);
  const [attempts, grants, quizzes] = await Promise.all([
    unwrap<any[]>(
      db
        .from("quiz_attempts")
        .select("quiz_id, attempt_number, score, total")
        .eq("student_id", caller.id),
    ),
    unwrap<any[]>(
      db.from("quiz_retake_grants").select("quiz_id, extra_attempts").eq("student_id", caller.id),
    ),
    unwrap<any[]>(db.from("quizzes").select(QUIZ_CONFIG_COLS).is("deleted_at", null)),
  ]);
  const configById = new Map<string, QuizConfig>(
    (quizzes ?? []).map((q: any) => [q.id as string, q as QuizConfig]),
  );
  const extraByQuiz = new Map<string, number>(
    (grants ?? []).map((g: any) => [g.quiz_id as string, (g.extra_attempts as number) ?? 0]),
  );
  const byQuiz = new Map<string, AttemptRow[]>();
  for (const a of attempts ?? []) {
    const arr = byQuiz.get(a.quiz_id) ?? [];
    arr.push({ attempt_number: a.attempt_number, score: a.score, total: a.total });
    byQuiz.set(a.quiz_id, arr);
  }
  return [...configById.values()].map((quiz) => {
    const list = byQuiz.get(quiz.id) ?? [];
    const ceiling = attemptCeiling(quiz, extraByQuiz.get(quiz.id) ?? 0);
    const eff = effectiveScore(list, quiz.retake_score_policy);
    const isScoreReleased = (quiz as QuizConfig).score_released === true;
    return {
      quiz_id: quiz.id,
      attempts_used: list.length,
      attempts_allowed: ceiling,
      can_retake: list.length === 0 || ceiling == null || list.length < ceiling,
      effective_score: isScoreReleased ? (eff?.score ?? null) : null,
      effective_total: isScoreReleased ? (eff?.total ?? null) : null,
      score_released: isScoreReleased,
      answer_key_released: (quiz as QuizConfig).answer_key_released === true,
    };
  });
}

export async function requireQuizOwnerOrAdmin(token: string, quizId: string) {
  const caller = await requireStaff(token);
  if (caller.role === "teacher") {
    const quiz = await getQuizConfig(quizId);
    const course = await unwrap<any>(
      db.from("courses").select("teacher_id").eq("id", quiz.course_id).maybeSingle(),
    );
    if (!course || course.teacher_id !== caller.id) {
      throw new Error("Forbidden: you can only manage worksheets for your own courses.");
    }
  }
  return caller;
}

export async function updateQuizRetakePolicy(
  id: string,
  patch: { allow_retake: boolean; max_attempts: number; retake_score_policy: RetakePolicy },
  token: string,
) {
  await requireQuizOwnerOrAdmin(token, id);
  await unwrap(db.from("quizzes").update(patch).eq("id", id));
}

export async function listQuizAttemptsForQuiz(quiz_id: string, token: string) {
  await requireQuizOwnerOrAdmin(token, quiz_id);
  const quiz = await getQuizConfig(quiz_id);
  const [attempts, grants, overrides] = await Promise.all([
    unwrap<any[]>(
      db
        .from("quiz_attempts")
        .select("student_id, attempt_number, score, total, created_at, tab_switches")
        .eq("quiz_id", quiz_id)
        .order("attempt_number"),
    ),
    unwrap<any[]>(
      db.from("quiz_retake_grants").select("student_id, extra_attempts").eq("quiz_id", quiz_id),
    ),
    unwrap<any[]>(
      db
        .from("quiz_score_overrides")
        .select("student_id, score, total, notes")
        .eq("quiz_id", quiz_id),
    ),
  ]);
  const studentIds = [...new Set<string>((attempts ?? []).map((a: any) => a.student_id as string))];
  // Include students who have an override but no attempts (manual entry).
  for (const o of overrides ?? []) {
    if (!studentIds.includes(o.student_id as string)) studentIds.push(o.student_id as string);
  }
  const profiles = studentIds.length
    ? await unwrap<any[]>(
        db.from("profiles").select("id, full_name, student_id, section").in("id", studentIds),
      )
    : [];
  const nameOf = new Map<string, any>((profiles ?? []).map((p: any) => [p.id as string, p]));
  const extraOf = new Map<string, number>(
    (grants ?? []).map((g: any) => [g.student_id as string, (g.extra_attempts as number) ?? 0]),
  );
  const overrideOf = new Map<string, any>(
    (overrides ?? []).map((o: any) => [o.student_id as string, o]),
  );
  const byStudent = new Map<string, AttemptRow[]>();
  for (const a of attempts ?? []) {
    const arr = byStudent.get(a.student_id) ?? [];
    arr.push({
      attempt_number: a.attempt_number,
      score: a.score,
      total: a.total,
      tab_switches: Array.isArray(a.tab_switches) ? a.tab_switches : [],
    });
    byStudent.set(a.student_id, arr);
  }
  const students = studentIds.map((sid) => {
    const list = byStudent.get(sid) ?? [];
    const eff = effectiveScore(list, quiz.retake_score_policy);
    const ov = overrideOf.get(sid);
    const p = nameOf.get(sid);
    // A teacher override supersedes the computed effective score.
    const overrideScore = ov?.score != null ? (ov.score as number) : null;
    const overrideTotal = ov?.total != null ? (ov.total as number) : null;
    return {
      student_id: sid,
      full_name: p?.full_name ?? "Unknown student",
      student_no: p?.student_id ?? null,
      section: p?.section ?? null,
      attempts: list,
      attempts_used: list.length,
      extra_attempts: extraOf.get(sid) ?? 0,
      effective_score: overrideScore ?? eff?.score ?? null,
      effective_total: overrideTotal ?? eff?.total ?? null,
      override_score: overrideScore,
      override_total: overrideTotal,
      override_notes: (ov?.notes as string | null) ?? null,
    };
  });
  return {
    quiz: {
      id: quiz.id,
      title: quiz.title,
      course_id: quiz.course_id,
      allow_retake: quiz.allow_retake,
      max_attempts: quiz.max_attempts,
      retake_score_policy: quiz.retake_score_policy,
    },
    students,
  };
}

/**
 * Teacher manual override of a student's effective worksheet score. The raw
 * AI attempt rows are preserved; the override is applied on top so it can be
 * revised or cleared without losing history.
 */
export async function overrideQuizAttempt(
  quiz_id: string,
  student_id: string,
  score: number | null,
  total: number | null,
  notes: string | null,
  token: string,
) {
  const caller = await requireQuizOwnerOrAdmin(token, quiz_id);
  const existing = await unwrap<any>(
    db
      .from("quiz_score_overrides")
      .select("id")
      .eq("quiz_id", quiz_id)
      .eq("student_id", student_id)
      .maybeSingle(),
  );
  // If a score is given without a total, default the total to the student's
  // latest attempt total so the override reads as a proper fraction instead of
  // "score/—". A null score (with null total) clears the override.
  let resolvedTotal = total;
  if (score != null && resolvedTotal == null) {
    const rows = await unwrap<any[]>(
      db
        .from("quiz_attempts")
        .select("attempt_number, total")
        .eq("quiz_id", quiz_id)
        .eq("student_id", student_id),
    );
    if (rows.length) {
      const latest = rows.reduce((a, b) => (b.attempt_number > a.attempt_number ? b : a));
      resolvedTotal = (latest.total as number | null) ?? null;
    }
  }
  const payload = {
    quiz_id,
    student_id,
    score,
    total: resolvedTotal,
    notes,
    overridden_by: caller.id,
    updated_at: new Date().toISOString(),
  };
  if (existing) await unwrap(db.from("quiz_score_overrides").update(payload).eq("id", existing.id));
  else await unwrap(db.from("quiz_score_overrides").insert(payload));
}

/** Full attempt detail incl. per-question results for one student. */
export async function listStudentAttemptDetail(quiz_id: string, student_id: string, token: string) {
  await requireQuizOwnerOrAdmin(token, quiz_id);
  const [quiz, profile, attempts, override] = await Promise.all([
    unwrap<any>(db.from("quizzes").select("id, title").eq("id", quiz_id).maybeSingle()),
    unwrap<any>(
      db
        .from("profiles")
        .select("id, full_name, student_id, section")
        .eq("id", student_id)
        .maybeSingle(),
    ),
    unwrap<any[]>(
      db
        .from("quiz_attempts")
        .select("attempt_number, score, total, created_at, results, tab_switches")
        .eq("quiz_id", quiz_id)
        .eq("student_id", student_id)
        .order("attempt_number"),
    ),
    unwrap<any>(
      db
        .from("quiz_score_overrides")
        .select("score, total, notes")
        .eq("quiz_id", quiz_id)
        .eq("student_id", student_id)
        .maybeSingle(),
    ),
  ]);
  return {
    quiz: { id: quiz?.id ?? quiz_id, title: quiz?.title ?? "Worksheet" },
    student: {
      id: student_id,
      full_name: profile?.full_name ?? "Unknown student",
      student_no: profile?.student_id ?? null,
      section: profile?.section ?? null,
    },
    attempts: (attempts ?? []).map((a: any) => ({
      attempt_number: a.attempt_number as number,
      score: a.score as number,
      total: a.total as number,
      created_at: (a.created_at as string) ?? "",
      results: Array.isArray(a.results) ? a.results : [],
      tab_switches: Array.isArray(a.tab_switches) ? a.tab_switches : [],
    })),
    override: override
      ? {
          score: (override.score as number | null) ?? null,
          total: (override.total as number | null) ?? null,
          notes: (override.notes as string | null) ?? null,
        }
      : null,
  };
}

export async function grantQuizRetake(quiz_id: string, student_id: string, token: string) {
  const caller = await requireQuizOwnerOrAdmin(token, quiz_id);
  const existing = await unwrap<any>(
    db
      .from("quiz_retake_grants")
      .select("id, extra_attempts")
      .eq("quiz_id", quiz_id)
      .eq("student_id", student_id)
      .maybeSingle(),
  );
  if (existing) {
    await unwrap(
      db
        .from("quiz_retake_grants")
        .update({ extra_attempts: (existing.extra_attempts as number) + 1, granted_by: caller.id })
        .eq("id", existing.id),
    );
  } else {
    await unwrap(
      db
        .from("quiz_retake_grants")
        .insert({ quiz_id, student_id, extra_attempts: 1, granted_by: caller.id }),
    );
  }
}

export async function resetQuizAttempts(quiz_id: string, student_id: string, token: string) {
  await requireQuizOwnerOrAdmin(token, quiz_id);
  await unwrap(
    db.from("quiz_attempts").delete().eq("quiz_id", quiz_id).eq("student_id", student_id),
  );
  await unwrap(
    db.from("quiz_retake_grants").delete().eq("quiz_id", quiz_id).eq("student_id", student_id),
  );
}

export async function createQuizWithQuestions(
  quiz: z.infer<typeof schemas.quizBundle>["quiz"],
  questions: z.infer<typeof schemas.quizBundle>["questions"],
) {
  const created = await unwrap<any>(db.from("quizzes").insert(quiz).select().single());
  await unwrap(
    db
      .from("quiz_questions")
      .insert(questions.map((q, i) => ({ ...q, quiz_id: created.id, position: i + 1 }))),
  );
}

/** List all quiz scores for a course — used by the gradebook. */
export async function listQuizScoresForCourse(course_id: string, token: string) {
  await requireStaff(token);
  const quizzes = await unwrap<any[]>(
    db
      .from("quizzes")
      .select("id, title, retake_score_policy")
      .eq("course_id", course_id)
      .is("deleted_at", null),
  );
  if (!quizzes.length) return [];

  const quizIds = quizzes.map((q) => q.id);
  const [attempts, overrides] = await Promise.all([
    unwrap<any[]>(
      db
        .from("quiz_attempts")
        .select("quiz_id, student_id, attempt_number, score, total")
        .in("quiz_id", quizIds),
    ),
    unwrap<any[]>(
      db
        .from("quiz_score_overrides")
        .select("quiz_id, student_id, score, total")
        .in("quiz_id", quizIds),
    ),
  ]);

  const byQuizStudent = new Map<string, Map<string, AttemptRow[]>>();
  for (const q of quizzes) {
    byQuizStudent.set(q.id, new Map());
  }
  for (const a of attempts) {
    const studentMap = byQuizStudent.get(a.quiz_id);
    if (!studentMap) continue;
    const arr = studentMap.get(a.student_id) ?? [];
    arr.push({ attempt_number: a.attempt_number, score: a.score, total: a.total });
    studentMap.set(a.student_id, arr);
  }

  // Teacher overrides keyed by quiz → student. If an override carries a score
  // but no total (possible when it was written before attempts existed), resolve
  // the total from the student's latest attempt — mirroring overrideQuizAttempt.
  const overrideMap = new Map<string, Map<string, { score: number; total: number }>>();
  for (const o of overrides) {
    if (o.score == null) continue;
    let total = o.total as number | null;
    if (total == null) {
      const attempts = byQuizStudent.get(o.quiz_id)?.get(o.student_id) ?? [];
      if (attempts.length) {
        total = attempts.reduce((a, b) => (b.attempt_number > a.attempt_number ? b : a)).total;
      }
    }
    if (total == null) continue;
    const m = overrideMap.get(o.quiz_id) ?? new Map();
    m.set(o.student_id, { score: o.score as number, total });
    overrideMap.set(o.quiz_id, m);
  }

  return quizzes.map((q) => {
    const studentMap = byQuizStudent.get(q.id)!;
    const scores: Record<string, { score: number; total: number }> = {};
    for (const [sid, attemptList] of studentMap) {
      const eff = effectiveScore(attemptList, q.retake_score_policy);
      if (eff) scores[sid] = eff;
    }
    // Overrides always win over computed scores.
    for (const [sid, ov] of overrideMap.get(q.id) ?? []) scores[sid] = ov;
    return {
      quiz_id: q.id,
      title: q.title,
      scores,
    };
  });
}

const ALLOWED_QUIZ_COLUMNS = new Set([
  "title",
  "description",
  "course_id",
  "duration_minutes",
  "allow_retake",
  "max_attempts",
  "retake_score_policy",
  "score_released",
  "answer_key_released",
  "question_count",
  "attachments",
  "deleted_at",
]);

export async function updateQuiz(
  tokenStr: string,
  id: string,
  patch: Record<string, unknown>,
  questions?: Array<{ question: string; options: string[]; correct_answer: string }>,
) {
  await requireQuizOwnerOrAdmin(tokenStr, id);
  const safePatch = Object.fromEntries(
    Object.entries(patch).filter(([key]) => ALLOWED_QUIZ_COLUMNS.has(key)),
  );
  if (Object.keys(safePatch).length)
    await unwrap(db.from("quizzes").update(safePatch).eq("id", id));
  if (questions && questions.length) {
    await unwrap(db.from("quiz_attempts").delete().eq("quiz_id", id));
    await unwrap(db.from("quiz_questions").delete().eq("quiz_id", id));
    await unwrap(
      db
        .from("quiz_questions")
        .insert(questions.map((q, i) => ({ ...q, quiz_id: id, position: i + 1 }))),
    );
  }
}

export async function deleteQuiz(tokenStr: string, id: string, mode: "soft" | "hard") {
  await requireQuizOwnerOrAdmin(tokenStr, id);
  if (mode === "soft") {
    await unwrap(db.from("quizzes").update({ deleted_at: new Date().toISOString() }).eq("id", id));
    return { mode };
  }
  const row = await unwrap<any>(
    db.from("quizzes").select("attachments").eq("id", id).maybeSingle(),
  );
  await unwrap(db.from("quiz_attempts").delete().eq("quiz_id", id));
  await unwrap(db.from("quiz_retake_grants").delete().eq("quiz_id", id));
  await unwrap(db.from("quiz_questions").delete().eq("quiz_id", id));
  await unwrap(db.from("quizzes").delete().eq("id", id));
  // Best-effort removal of binary objects
  const attachments = Array.isArray(row?.attachments)
    ? (row.attachments as Array<{ path?: string }>)
    : [];
  const paths = attachments
    .map((a) => a.path)
    .filter((p): p is string => typeof p === "string" && p.length > 0);
  if (paths.length) {
    try {
      const { supabaseAdmin } = await import("@/integrations/db/client.server");
      await supabaseAdmin.storage.from("course-materials").remove(paths);
    } catch {
      /* best-effort */
    }
  }
  return { mode };
}
