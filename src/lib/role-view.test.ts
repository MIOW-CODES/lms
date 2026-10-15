import { describe, it, expect } from "bun:test";
import {
  TEST_ACCOUNT_EMAIL,
  TEST_STUDENT_EMAIL,
  isTestAccount,
  isTestStudent,
  assertTestAccount,
  parseRoleView,
  applyRoleView,
} from "./role-view";

describe("role-view allowlist", () => {
  it("recognizes only the test account email (case-insensitive, trimmed)", () => {
    expect(isTestAccount(TEST_ACCOUNT_EMAIL)).toBe(true);
    expect(isTestAccount("Test@G.Msuiit.Edu.PH ")).toBe(true);
    expect(isTestAccount("test@g.msuiit.edu.ph")).toBe(true);
  });

  it("rejects every other account", () => {
    expect(isTestAccount("josephalan.vergara@g.msuiit.edu.ph")).toBe(false);
    expect(isTestAccount("teacher@g.msuiit.edu.ph")).toBe(false);
    expect(isTestAccount("test@g.msuiit.edu.ph.evil.com")).toBe(false);
    expect(isTestAccount("xtest@g.msuiit.edu.ph")).toBe(false);
    expect(isTestAccount("")).toBe(false);
    expect(isTestAccount(null)).toBe(false);
    expect(isTestAccount(undefined)).toBe(false);
  });

  describe("isTestStudent", () => {
    it("recognizes designated test student accounts", () => {
      expect(isTestStudent(TEST_STUDENT_EMAIL)).toBe(true);
      expect(isTestStudent("IT10@G.MSUIIT.EDU.PH ")).toBe(true);
      expect(isTestStudent("it10")).toBe(true);
      expect(isTestStudent(TEST_ACCOUNT_EMAIL)).toBe(true);
    });

    it("rejects non-test student accounts", () => {
      expect(isTestStudent("regular.student@g.msuiit.edu.ph")).toBe(false);
      expect(isTestStudent("")).toBe(false);
      expect(isTestStudent(null)).toBe(false);
      expect(isTestStudent(undefined)).toBe(false);
    });
  });

  describe("assertTestAccount (security guard for the switch fn)", () => {
    it("passes for the allowlisted email", () => {
      expect(() => assertTestAccount(TEST_ACCOUNT_EMAIL)).not.toThrow();
    });

    it("throws Forbidden for any other email", () => {
      expect(() => assertTestAccount("admin@g.msuiit.edu.ph")).toThrow("Forbidden");
      expect(() => assertTestAccount("alan.vergara@g.msuiit.edu.ph")).toThrow("Forbidden");
      expect(() => assertTestAccount(null)).toThrow("Forbidden");
      expect(() => assertTestAccount(undefined)).toThrow("Forbidden");
    });
  });

  describe("parseRoleView", () => {
    it("narrows valid views", () => {
      expect(parseRoleView("teacher")).toBe("teacher");
      expect(parseRoleView("admin")).toBe("admin");
      expect(parseRoleView("student")).toBe("student");
    });

    it("rejects anything else", () => {
      expect(parseRoleView("superuser")).toBeNull();
      expect(parseRoleView("")).toBeNull();
      expect(parseRoleView(42)).toBeNull();
      expect(parseRoleView(null)).toBeNull();
      expect(parseRoleView(undefined)).toBeNull();
    });
  });

  describe("applyRoleView", () => {
    const base = { email: TEST_ACCOUNT_EMAIL, role: "teacher" as const, id: "p1" };

    it("honors the stored view for the test account", () => {
      expect(applyRoleView(base, "admin").role).toBe("admin");
      expect(applyRoleView(base, "student").role).toBe("student");
      expect(applyRoleView(base, "teacher").role).toBe("teacher");
    });

    it("keeps the real role for every other account even when a view is stored", () => {
      const teacher = { email: "real.teacher@g.msuiit.edu.ph", role: "teacher" as const };
      const admin = { email: "real.admin@g.msuiit.edu.ph", role: "admin" as const };
      const student = { email: "real.student@g.msuiit.edu.ph", role: "student" as const };
      expect(applyRoleView(teacher, "admin").role).toBe("teacher");
      expect(applyRoleView(admin, "student").role).toBe("admin");
      expect(applyRoleView(student, "admin").role).toBe("student");
    });

    it("ignores invalid stored views", () => {
      expect(applyRoleView(base, "root").role).toBe("teacher");
      expect(applyRoleView(base, null).role).toBe("teacher");
    });

    it("returns the profile unchanged (same ref) when no override applies", () => {
      expect(applyRoleView(base, "teacher")).toBe(base);
    });
  });
});
