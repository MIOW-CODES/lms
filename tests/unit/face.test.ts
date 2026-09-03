import { describe, expect, it } from "bun:test";
import {
  DESCRIPTOR_LENGTH,
  FACE_MATCH_THRESHOLD,
  embeddingDistance,
  isMatch,
} from "../../src/lib/face";

const zeros = () => new Array<number>(DESCRIPTOR_LENGTH).fill(0);
const ones = () => new Array<number>(DESCRIPTOR_LENGTH).fill(1);

describe("face embedding helpers", () => {
  it("distance 0 and match for identical descriptors", () => {
    const a = zeros();
    const b = zeros();
    expect(embeddingDistance(a, b)).toBe(0);
    expect(isMatch(a, b)).toBe(true);
  });

  it("all-zeros vs all-ones (128-D) do not match", () => {
    const d = embeddingDistance(zeros(), ones());
    if (d === null) throw new Error("expected a numeric distance");
    expect(d).toBe(Math.sqrt(DESCRIPTOR_LENGTH));
    expect(d).toBeGreaterThan(FACE_MATCH_THRESHOLD);
    expect(isMatch(zeros(), ones())).toBe(false);
  });

  it("malformed inputs never match and never throw", () => {
    const bad: unknown[] = [
      null,
      undefined,
      42,
      "not-json{{{",
      "[1,2,3]",
      { length: DESCRIPTOR_LENGTH },
      new Array<number>(DESCRIPTOR_LENGTH - 1).fill(0),
      new Array<number>(DESCRIPTOR_LENGTH + 1).fill(0),
      new Array<number>(DESCRIPTOR_LENGTH).fill(Number.NaN),
      new Array<number>(DESCRIPTOR_LENGTH).fill(Number.POSITIVE_INFINITY),
      new Array<unknown>(DESCRIPTOR_LENGTH).fill("0"),
      new Float32Array(DESCRIPTOR_LENGTH - 1),
    ];
    for (const v of bad) {
      expect(embeddingDistance(v, zeros())).toBeNull();
      expect(embeddingDistance(zeros(), v)).toBeNull();
      expect(isMatch(v, zeros())).toBe(false);
      expect(isMatch(zeros(), v)).toBe(false);
    }
    expect(embeddingDistance(null, undefined)).toBeNull();
    expect(isMatch(null, undefined)).toBe(false);
  });
});
