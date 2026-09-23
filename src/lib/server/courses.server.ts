/* eslint-disable @typescript-eslint/no-explicit-any */
// Courses, assignments, enrollments, submissions.
import { z } from "zod";
import { db } from "@/integrations/db/client.server";
import { unwrap, withoutToken } from "@/lib/server/utils.server";
import { requireStaff } from "@/lib/server/auth.server";
import { schemas } from "@/lib/server/schemas.server";

export async function listCourses() {
  const courses = await unwrap<any[]>(db.from("courses").select("*").order("code"));
  const teachers = await unwrap<Array<{ id: string; full_name: string }>>(
    db
      .from("profiles")
      .select("id, full_name")
      .in("role", ["teacher", "admin"])
      .is("deleted_at", null),
  );
  const byId = new Map(teachers.map((t) => [t.id, t.full_name]));
  return courses.map((c) => ({
    ...c,
    teacher_name: c.teacher_id ? byId.get(c.teacher_id) : undefined,
  }));
}

async function assertTeacherAssignable(teacherId: unknown) {
  if (teacherId == null) return;
  const t = await unwrap<any>(
    db.from("profiles").select("id, role").eq("id", teacherId).is("deleted_at", null).maybeSingle(),
  );
  if (!t || t.role !== "teacher") {
    throw new Error("Course leads must be users with the teacher role");
  }
}

export async function createCourse(input: z.infer<typeof schemas.courseInput>) {
  await assertTeacherAssignable(input["teacher_id"]);
  await unwrap(db.from("courses").insert(withoutToken(input)));
}

export async function authorizeCourseUpdate(
  token: string,
  id: string,
  patch: Record<string, unknown>,
) {
  const caller = await requireStaff(token);
  if (caller.role === "admin") return patch;

  const course = await unwrap<any>(
    db.from("courses").select("teacher_id").eq("id", id).maybeSingle(),
  );
  if (!course || course.teacher_id !== caller.id) {
    throw new Error("Forbidden: you can only edit courses you lead.");
  }
  const { teacher_id: _ignored, ...rest } = patch;
  return rest;
}

const ALLOWED_COURSE_COLUMNS = new Set([
  "title",
  "code",
  "teacher_id",
  "grade_level",
  "color",
  "education_level",
  "college_year",
  "strand",
  "program",
  "grading_system",
  "days_of_week",
  "start_time",
  "end_time",
  "late_threshold_minutes",
  "deleted_at",
]);

export async function updateCourse(id: string, patch: Record<string, unknown>) {
  const safePatch = Object.fromEntries(
    Object.entries(patch).filter(([key]) => ALLOWED_COURSE_COLUMNS.has(key)),
  );
  if ("teacher_id" in safePatch) await assertTeacherAssignable(safePatch["teacher_id"]);
  if (Object.keys(safePatch).length)
    await unwrap(db.from("courses").update(safePatch).eq("id", id));
}

export async function deleteCourse(id: string) {
  await unwrap(db.from("courses").delete().eq("id", id));
}

export async function listAssignments() {
  return unwrap<any[]>(db.from("assignments").select("*").is("deleted_at", null).order("due_date"));
}

export async function createAssignment(input: z.infer<typeof schemas.assignmentInput>) {
  await unwrap(db.from("assignments").insert(withoutToken(input)));
}

export async function enrollmentsForCourse(courseId: string): Promise<string[]> {
  const rows = await unwrap<Array<{ student_id: string }>>(
    db.from("enrollments").select("student_id").eq("course_id", courseId),
  );
  return rows.map((r) => r.student_id);
}

export async function enrollmentsForStudent(studentId: string): Promise<string[]> {
  const rows = await unwrap<Array<{ course_id: string }>>(
    db.from("enrollments").select("course_id").eq("student_id", studentId),
  );
  return rows.map((r) => r.course_id);
}

export async function enrollStudent(student_id: string, course_id: string) {
  const existing = await unwrap<{ id: string } | null>(
    db
      .from("enrollments")
      .select("id")
      .eq("student_id", student_id)
      .eq("course_id", course_id)
      .maybeSingle(),
  );
  if (!existing) await unwrap(db.from("enrollments").insert({ student_id, course_id }));
}

export async function listSubmissionsForStudent(studentId: string) {
  return unwrap<any[]>(db.from("submissions").select("*").eq("student_id", studentId));
}

/** All submissions for one assignment joined with student identity — staff view. */
export async function listSubmissionsForAssignment(assignmentId: string, token: string) {
  await requireStaff(token);
  const rows = await unwrap<any[]>(
    db
      .from("submissions")
      // Explicit columns — never expose future/internal columns via SELECT *.
      .select(
        "id, assignment_id, student_id, content, file_urls, score, feedback, status, submitted_at",
      )
      .eq("assignment_id", assignmentId),
  );
  if (!rows.length) return [];
  const studentIds = [...new Set(rows.map((r) => r.student_id as string))];
  const profiles = await unwrap<any[]>(
    db.from("profiles").select("id, full_name, student_id, section").in("id", studentIds),
  );
  const byId = new Map(profiles.map((p) => [p.id as string, p]));
  return rows.map((r) => {
    const p = byId.get(r.student_id as string);
    return {
      id: r.id,
      student_id: r.student_id,
      full_name: p?.full_name ?? "Unknown student",
      student_no: p?.student_id ?? null,
      section: p?.section ?? null,
      content: r.content ?? null,
      file_urls: Array.isArray(r.file_urls) ? r.file_urls : [],
      score: r.score ?? null,
      feedback: r.feedback ?? null,
      status: r.status,
      submitted_at: r.submitted_at ?? null,
    };
  });
}

/** Teacher manually grades a submission (score/feedback/status). */
export async function gradeSubmission(
  token: string,
  submissionId: string,
  patch: {
    score: number | null;
    feedback: string | null;
    status?: "pending" | "submitted" | "graded" | undefined;
  },
) {
  const submission = await unwrap<any>(
    db.from("submissions").select("id, assignment_id").eq("id", submissionId).maybeSingle(),
  );
  if (!submission) throw new Error("Submission not found");
  // Reuse the assignment-ownership guard so teachers only grade their own courses.
  const { requireAssignmentOwnerOrAdmin } = await import("@/lib/server/materials.server");
  await requireAssignmentOwnerOrAdmin(token, submission.assignment_id as string);
  const row: Record<string, unknown> = {
    score: patch.score,
    feedback: patch.feedback,
  };
  row["status"] = patch.status ?? (patch.score != null ? "graded" : "submitted");
  await unwrap(db.from("submissions").update(row).eq("id", submissionId));
}

export async function submitAssignment(input: z.infer<typeof schemas.submissionInput>) {
  const existing = await unwrap<{ id: string } | null>(
    db
      .from("submissions")
      .select("id")
      .eq("assignment_id", input.assignment_id)
      .eq("student_id", input.student_id)
      .maybeSingle(),
  );
  const row = withoutToken(input);
  if (existing) {
    await unwrap(db.from("submissions").update(row).eq("id", existing.id));
    return { id: existing.id };
  }
  const created = await unwrap<{ id: string }>(
    db.from("submissions").insert(row).select("id").single(),
  );
  return { id: created.id };
}

export async function requireCourseOwnerOrAdmin(token: string, courseId: string) {
  const caller = await requireStaff(token);
  if (caller.role === "teacher") {
    const course = await unwrap<any>(
      db.from("courses").select("teacher_id").eq("id", courseId).maybeSingle(),
    );
    if (!course || course.teacher_id !== caller.id) {
      throw new Error("Forbidden: you can only manage content for your own courses.");
    }
  }
  return caller;
}
