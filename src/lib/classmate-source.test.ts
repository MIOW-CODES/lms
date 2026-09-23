import { describe, expect, it } from "bun:test";
import { aggregateSourceMaterial } from "@/lib/classmate-source";

describe("aggregateSourceMaterial", () => {
  it("returns an empty string for no files", () => {
    expect(aggregateSourceMaterial([])).toBe("");
  });

  it("passes a single file through verbatim", () => {
    const text = "Section I: Multiple Choice\n1. What is 7 × 8?";
    expect(aggregateSourceMaterial([{ name: "lecture.pdf", size: 100, text }])).toBe(text);
  });

  it("labels and separates multiple files", () => {
    const out = aggregateSourceMaterial([
      { name: "slides.pdf", size: 10, text: "  Slide content  " },
      { name: "handout.docx", size: 20, text: "Handout content" },
    ]);
    expect(out).toContain("--- SOURCE MATERIAL 1: slides.pdf ---");
    expect(out).toContain("--- SOURCE MATERIAL 2: handout.docx ---");
    expect(out).toContain("Slide content");
    expect(out).toContain("Handout content");
    // Files are separated by a blank line, order preserved.
    expect(out.indexOf("slides.pdf")).toBeLessThan(out.indexOf("handout.docx"));
    expect(out).toContain("---\nSlide content\n\n---");
  });

  it("trims each file's text", () => {
    const out = aggregateSourceMaterial([
      { name: "a.txt", size: 1, text: "\n\nA\n\n" },
      { name: "b.txt", size: 1, text: "\tB\t" },
    ]);
    expect(out).toContain("--- SOURCE MATERIAL 1: a.txt ---\nA");
    expect(out).toContain("--- SOURCE MATERIAL 2: b.txt ---\nB");
  });
});
