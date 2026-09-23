import { describe, expect, it } from "bun:test";
import { schemas } from "./schemas.server";

/* Regression guard for the profile/student-enroll schema refactor. */

describe("schemas.profileInput", () => {
  it("accepts a minimal student payload", () => {
    const parsed = schemas.profileInput.parse({
      full_name: "Ana Reyes",
      student_id: "2026-0042",
      token: "t",
    });
    expect(parsed.full_name).toBe("Ana Reyes");
  });

  it("accepts the full optional student field set", () => {
    const parsed = schemas.profileInput.parse({
      full_name: "Ana Reyes",
      student_id: "2026-0042",
      email: "ana.reyes@g.msuiit.edu.ph",
      role: "student",
      grade_level: 12,
      section: "B8",
      pin: "123456",
      rfid_uid: "1234567890",
      avatar_url: "https://example.com/a.png",
      token: "t",
    });
    expect(parsed.grade_level).toBe(12);
  });

  it("rejects an invalid PIN", () => {
    expect(() =>
      schemas.profileInput.parse({ full_name: "X", student_id: "1", pin: "abc", token: "t" }),
    ).toThrow();
  });
});

describe("schemas.studentEnroll", () => {
  it("accepts a student with a course to enroll into", () => {
    const parsed = schemas.studentEnroll.parse({
      full_name: "Ana Reyes",
      student_id: "2026-0042",
      course_id: "11111111-1111-4111-8111-111111111111",
      token: "t",
    });
    expect(parsed.course_id).toBe("11111111-1111-4111-8111-111111111111");
  });

  it("accepts a student with no course (bare record)", () => {
    const parsed = schemas.studentEnroll.parse({
      full_name: "Ana Reyes",
      student_id: "2026-0042",
      token: "t",
    });
    expect(parsed.course_id).toBeUndefined();
  });

  it("rejects a malformed course id", () => {
    expect(() =>
      schemas.studentEnroll.parse({
        full_name: "Ana Reyes",
        student_id: "2026-0042",
        course_id: "not-a-uuid",
        token: "t",
      }),
    ).toThrow();
  });
});
