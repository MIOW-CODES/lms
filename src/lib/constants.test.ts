import { describe, expect, it } from "bun:test";
import {
  ALL_SECTIONS_LABEL,
  ALL_SECTIONS_VALUE,
  DEFAULT_DEPARTMENTS,
  DEFAULT_STUDENT_SECTIONS,
  resolveSectionFilter,
} from "./constants";

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

  it("resolveSectionFilter maps the reset label and empty value to the all sentinel", () => {
    expect(ALL_SECTIONS_VALUE).toBe("all");
    expect(resolveSectionFilter("")).toBe(ALL_SECTIONS_VALUE);
    expect(resolveSectionFilter(ALL_SECTIONS_LABEL)).toBe(ALL_SECTIONS_VALUE);
    // The literal reset label must never leak through as a real section name.
    expect(resolveSectionFilter(ALL_SECTIONS_LABEL)).not.toBe(ALL_SECTIONS_LABEL);
  });

  it("resolveSectionFilter passes through a real section name", () => {
    expect(resolveSectionFilter("Rizal")).toBe("Rizal");
    expect(resolveSectionFilter("Custom Section")).toBe("Custom Section");
  });
});
