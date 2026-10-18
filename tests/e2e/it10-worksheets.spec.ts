import { test, expect } from "@playwright/test";
import { Pool } from "pg";

// This regression deliberately uses the local IT10 tester: its historical
// deadlines must never be interpreted before its test-account profile loads.
const databaseUrl = process.env["DATABASE_URL"];
const localDatabase =
  databaseUrl && ["localhost", "127.0.0.1", "::1"].includes(new URL(databaseUrl).hostname);
const describeLocal = localDatabase ? test.describe : test.describe.skip;

test.use({
  headless: true,
  ...(process.env["PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"]
    ? {
        launchOptions: { executablePath: process.env["PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH"] },
      }
    : {}),
});

describeLocal("IT10 worksheet startup", () => {
  for (const viewport of [
    { width: 1280, height: 960 },
    { width: 390, height: 844 },
  ]) {
    test(`starts without recording an attempt and includes all four formats (${viewport.width}px)`, async ({
      page,
    }) => {
      test.setTimeout(120_000);
      // This suite runs only against an explicitly local database. Normalize
      // the disposable IT10 tester credential so it follows current PIN policy.
      const pool = new Pool({ connectionString: databaseUrl });
      try {
        await pool.query(
          "UPDATE profiles SET pin = '1010', pin_hash = NULL, pin_must_change = false WHERE username = 'it10' OR student_id = 'it10'",
        );
      } finally {
        await pool.end();
      }
      await page.setViewportSize(viewport);
      await page.goto("/auth");
      // Authenticate through the same RPC as the login UI. This awaits module
      // hydration explicitly and avoids native pre-hydration form submission.
      await page.evaluate(async () => {
        const modulePath = "/src/lib/lms.ts";
        const lms = await import(modulePath);
        const result = await lms.pinLogin("it10", "1010");
        if (!result.ok) throw new Error("Local IT10 tester login failed");
        lms.saveSession(result.profile);
      });
      const attempts = () =>
        page.evaluate(async () => {
          const modulePath = "/src/lib/lms.ts";
          const lms = await import(modulePath);
          const summaries = await lms.myQuizSummaries();
          return summaries
            .map(
              (row: { quiz_id: string; attempts_used: number }) =>
                `${row.quiz_id}:${row.attempts_used}`,
            )
            .sort();
        });
      const before = await attempts();
      await page.goto("/dashboard/student/courses");
      await page
        .getByRole("button", { name: /Open course IT10 / })
        .first()
        .click();
      const courseUrl = page.url();
      for (const title of [
        "Quiz — Arduino Part 2",
        "Quiz — Resistor Color Code",
        "Quiz — Programming with Arduino",
        "1st Quarter Exam",
      ]) {
        const row = page
          .getByTestId("student-worksheet-title")
          .filter({ hasText: title })
          .locator("../..");
        await row.getByRole("button", { name: /Start|Retake/ }).click();
        await page.getByRole("button", { name: "Start worksheet", exact: true }).click();
        await expect(page.getByTestId("question-nav-1")).toBeVisible();
        // Wait through a real countdown tick: the previous bug could briefly
        // render the question before an initialization race submitted it.
        await page.waitForTimeout(1200);
        await expect(page.getByTestId("question-nav-1")).toBeVisible();
        const total = title === "1st Quarter Exam" ? 50 : 20;
        await expect(page.locator('[data-testid^="question-nav-"]')).toHaveCount(total);
        const formats = new Set<string>();
        for (let i = 1; i <= total; i++) {
          await page.getByTestId(`question-nav-${i}`).click();
          const dialog = page.getByRole("dialog");
          for (const kind of ["Matching", "Essay", "Multiple choice", "Identification"]) {
            if (await dialog.getByText(kind, { exact: true }).count()) formats.add(kind);
          }
          const matching = dialog.getByLabel("Column B — choose the matching description");
          if (await matching.count()) {
            await matching.selectOption({ index: 1 });
            const chosen = await matching.inputValue();
            await page.getByTestId("question-nav-1").click();
            await page.getByTestId(`question-nav-${i}`).click();
            await expect(matching).toHaveValue(chosen);
          }
        }
        expect([...formats].sort()).toEqual([
          "Essay",
          "Identification",
          "Matching",
          "Multiple choice",
        ]);
        expect(page.url()).toBe(courseUrl);
        await page.getByRole("button", { name: "Close dialog", exact: true }).click();
        await expect(page.getByTestId("question-nav-1")).toBeHidden();
      }
      expect(await attempts()).toEqual(before);
    });
  }
});
