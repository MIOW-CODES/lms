import { describe, expect, it } from "bun:test";
import { DEFAULT_DEPARTMENTS, DEFAULT_STUDENT_SECTIONS } from "./constants";

describe("constants", () => {
  it("exports non-empty DEFAULT_DEPARTMENTS containing standard school departments", () => {
    expect(Array.isArray(DEFAULT_DEPARTMENTS)).toBe(true);
    expect(DEFAULT_DEPARTMENTS.length).toBeGreaterThanOrEqual(8);
    expect(DEFAULT_DEPARTMENTS).toContain("Mathematics");
    expect(DEFAULT_DEPARTMENTS).toContain("Science");
    expect(DEFAULT_DEPARTMENTS).toContain("English");
    expect(DEFAULT_DEPARTMENTS).toContain("Computer Studies");
  });

  it("exports non-empty DEFAULT_STUDENT_SECTIONS containing typical section names", () => {
    expect(Array.isArray(DEFAULT_STUDENT_SECTIONS)).toBe(true);
    expect(DEFAULT_STUDENT_SECTIONS.length).toBeGreaterThanOrEqual(6);
    expect(DEFAULT_STUDENT_SECTIONS).toContain("Rizal");
    expect(DEFAULT_STUDENT_SECTIONS).toContain("Bonifacio");
    expect(DEFAULT_STUDENT_SECTIONS).toContain("Mabini");
  });
});
