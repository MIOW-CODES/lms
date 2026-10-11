/* eslint-disable @typescript-eslint/no-explicit-any */
// Auth guards — session resolution with role checks.
import { db } from "@/integrations/db/client.server";
import { unwrap } from "@/lib/server/utils.server";
import { verifySessionToken, sessionJti } from "@/lib/server/sessions.server";
import { getProfileById } from "@/lib/server/profiles.server";
import { applyRoleView, isTestAccount } from "@/lib/role-view";

/**
 * Verify the caller's token and load their profile. Throws if invalid.
 *
 * Role-view shim: the allowlisted demo test account can pick a portal view
 * (teacher/admin/student) stored on ITS session row (sessions.role_view). The
 * view is applied here — the single session read path every guard goes
 * through — so all guards consistently honor it, and ONLY for that email
 * (see applyRoleView). The real profiles.role never changes.
 */
export async function requireSession(token: string) {
  const id = verifySessionToken(token);
  // jti revocation check — legacy tokens without jti skip DB check (compat)
  let storedRoleView: string | null = null;
  try {
    const jti = sessionJti(token);
    if (jti) {
      const row = await unwrap<any>(
        db.from("sessions").select("revoked_at, role_view").eq("jti", jti).maybeSingle(),
      );
      if (!row || (row as any).revoked_at) throw new Error("Unauthorized");
      storedRoleView = (row as any).role_view ?? null;
    }
  } catch (e: any) {
    if (e?.message === "Unauthorized") throw e;
    // DB unavailable — reject token to prevent revoked-session abuse.
    console.error("[auth] JTI revocation check failed (DB may be down):", e?.message ?? e);
    throw new Error("Unauthorized");
  }
  const profile = await getProfileById(id);
  if (!profile) throw new Error("Unauthorized");
  return applyRoleView(profile, storedRoleView);
}

/** Caller must be a teacher or admin. */
export async function requireStaff(token: string) {
  const profile = await requireSession(token);
  if (profile.role === "student") throw new Error("Forbidden");
  return profile;
}

/** Caller must be an admin. */
export async function requireAdmin(token: string) {
  const profile = await requireSession(token);
  if (profile.role !== "admin") throw new Error("Forbidden");
  return profile;
}

/**
 * Caller must be a teacher. Students are always rejected; admins keep being
 * rejected too (gradebook/settings mutations are teacher-owned) — EXCEPT the
 * allowlisted test account acting from its admin view, which exercises
 * teacher-only paths on top of the admin console (role-view shim).
 */
export async function requireTeacher(token: string) {
  const profile = await requireSession(token);
  if (profile.role === "teacher") return profile;
  if (profile.role === "admin" && isTestAccount(profile.email)) return profile;
  throw new Error("Forbidden");
}

/** Caller must be the given student, or staff. */
export async function requireSelfOrStaff(token: string, studentId: string) {
  const profile = await requireSession(token);
  if (profile.role === "student" && profile.id !== studentId) throw new Error("Forbidden");
  return profile;
}

/* ---------- Course-membership guards (Gate-1 amendment #3) ---------- */

/** Course ids the student is enrolled in. */
export async function enrolledCourseIds(studentId: string): Promise<string[]> {
  const rows = await unwrap<Array<{ course_id: string }>>(
    db.from("enrollments").select("course_id").eq("student_id", studentId),
  );
  return rows.map((r) => r.course_id);
}

/** True when the student is enrolled in the course. */
export async function isEnrolledIn(studentId: string, courseId: string): Promise<boolean> {
  const row = await unwrap<{ course_id: string } | null>(
    db
      .from("enrollments")
      .select("course_id")
      .eq("student_id", studentId)
      .eq("course_id", courseId)
      .maybeSingle(),
  );
  return !!row;
}

/**
 * Course-content guard: staff (teacher/admin) see everything; students must be
 * enrolled in the course. Throws "Forbidden" otherwise. Doubles as the C13
 * centralization seam alongside availability.requireOpen.
 */
export async function requireEnrollment(
  courseId: string,
  profile: { id: string; role: string },
): Promise<void> {
  if (profile.role !== "student") return;
  if (!(await isEnrolledIn(profile.id, courseId))) {
    throw new Error("Forbidden: you are not enrolled in this course.");
  }
}
