import { describe, expect, it } from "bun:test";

describe("seed-iae106 metadata", () => {
  it("imports without throwing", async () => {
    const mod = await import("./seed-iae106.server");
    expect(typeof mod.seedIae106CourseAndQuizzes).toBe("function");
  });
});
