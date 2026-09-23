/**
 * Shared enrollment types + error copy used by both the server domain module and
 * the client RPC layer, so messages stay in sync and are easy to translate.
 */

/** Client-side shape for create-or-enroll (mirrors `schemas.studentEnroll`). */
export interface StudentEnrollInput {
  full_name: string;
  student_id?: string | null;
  email?: string | null;
  role?: "student" | "teacher" | "admin";
  grade_level?: number | null;
  section?: string | null;
  employee_id?: string | null;
  prefix?: string | null;
  department?: string | null;
  pin?: string | null;
  rfid_uid?: string | null;
  avatar_url?: string | null;
}

export const ENROLLMENT_ERRORS = {
  notFound: "Student not found",
  nonStudent: (role: string) => `That identity belongs to a ${role} account, not a student.`,
} as const;
