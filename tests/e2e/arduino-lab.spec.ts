import { test as base, expect, type Page, type BrowserContext } from "@playwright/test";
import { Pool } from "pg";

/**
 * Arduino manual-wiring E2E (mobile 390×844).
 *
 * Verifies the Tinkercad-style experience end to end:
 *  - students place parts from the palette and wire terminals MANUALLY
 *    (nothing is pre-wired; no auto bezier wires)
 *  - an LED wired anode→D8 / cathode→resistor→GND lights on
 *    digitalWrite(8, HIGH) while an unwired LED2 stays dark on D13
 *  - the Connections summary reflects the wires and inserts into the answer
 *  - the Arduino Lab route shows the seeded task chips with a dashed ghost
 *    wiring guide
 *
 * Requires a real database session (prod Supabase envs are fine).
 *
 * NOTE: the login rate limiter allows only 5 attempts / 15 min per account,
 * so authentication happens ONCE per worker (worker-scoped storage state)
 * and every test reuses that session.
 */

const describeRealDB =
  process.env.PLAYWRIGHT_REAL_DB || process.env.DATABASE_URL ? base.describe : base.describe.skip;

const TEST_TIMEOUT = 240_000;

/** Hydration-safe PIN login: retries until the React submit handler runs and
 *  the server lands us on the dashboard (native pre-hydration submits reload).
 *  Completes the forced-PIN-change gate when it appears; falls back to the test
 *  PIN below when a previous run already rotated the account's PIN. */
async function pinLogin(page: Page, id: string, pin: string) {
  for (const attemptPin of [pin, "9999"]) {
    for (let i = 0; i < 6; i++) {
      await page.goto("/auth");
      await page.waitForTimeout(1500);
      try {
        await page.locator("#auth-tab-pin").click({ timeout: 2000 });
        await page.waitForTimeout(400);
        await page.locator("#login-id").fill(id, { timeout: 2000 });
        await page.locator("#login-pin").fill(attemptPin, { timeout: 2000 });
        const btn = page.locator("#auth-panel-pin button[type=submit]");
        if (!(await btn.isEnabled({ timeout: 2000 }))) continue;
        // The submit must reach the login server function — a pre-hydration click
        // falls back to a native form GET that just reloads the page.
        const loginReq = page
          .waitForRequest((r) => r.url().includes("/_serverFn/") && r.method() === "POST", {
            timeout: 6000,
          })
          .catch(() => null);
        await btn.click({ timeout: 5000 });
        if (!(await loginReq)) continue;
        await page.waitForURL(/\/dashboard\//, { timeout: 12000 }).catch(() => {});
        if (page.url().includes("/dashboard")) {
          await completePinGate(page);
          return;
        }
      } catch {
        // not hydrated yet — retry
      }
      await page.waitForTimeout(500);
    }
  }
  throw new Error("PIN login never completed");
}

/** Forced-PIN-change gate: student PINs default to the student number, so the
 *  migration flags every student (pin_must_change) and the student layout
 *  blocks until a private PIN is chosen. Set the test PIN and proceed. */
async function completePinGate(page: Page, newPin = "9999") {
  const gate = page.getByTestId("pin-gate");
  if (!(await gate.isVisible({ timeout: 5000 }).catch(() => false))) return;
  await page.getByTestId("pin-gate-new").fill(newPin);
  await page.getByTestId("pin-gate-confirm").fill(newPin);
  await page.getByTestId("pin-gate-submit").click();
  await gate.waitFor({ state: "hidden", timeout: 20000 });
}

/** Login once per worker; every test reuses the authenticated storage state. */
const test = base.extend<
  object,
  { sessionState: Awaited<ReturnType<BrowserContext["storageState"]>> }
>({
  sessionState: [
    async ({ browser }, provide) => {
      const ctx = await browser.newContext({
        baseURL: process.env["PLAYWRIGHT_BASE_URL"] ?? "http://localhost:3000",
      });
      const page = await ctx.newPage();
      // Student 2026-0099 — PIN is the student ID (student_pin_is_id migration)
      await pinLogin(page, "2026-0099", "2026-0099");
      await page.waitForURL(/\/dashboard\/student/, { timeout: 30000 });
      const state = await ctx.storageState();
      await ctx.close();
      await provide(state);
    },
    { scope: "worker" },
  ],
  storageState: async ({ sessionState }, provide) => {
    await provide(sessionState);
  },
});

test.use({ viewport: { width: 390, height: 844 } });

/** The exam hard-lock overlay appears if fullscreen was entered and lost. */
async function dismissExamLock(page: Page) {
  const overlay = page.getByText("Exam lockdown active");
  if (await overlay.isVisible().catch(() => false)) {
    await page.getByRole("button", { name: "Return to fullscreen" }).click();
    await page.waitForTimeout(300);
  }
}

/** Place parts and wire LED1 anode→D8, cathode→resistor→GND — fully manually. */
async function wireLedWithResistor(page: Page) {
  await page.locator('[data-testid="palette-wokwi-led"]').click();
  await page.locator('[data-testid="palette-wokwi-led"]').click();
  await page.locator('[data-testid="palette-wokwi-resistor"]').click();

  await page.locator('[data-testid="tool-wire"]').click();
  const wire = async (from: string, to: string) => {
    await page.locator(`[data-testid="${from}"]`).click();
    await page.locator(`[data-testid="${to}"]`).click();
  };
  await wire("term-part-LED1-A", "term-uno-D8");
  await wire("term-part-LED1-K", "term-part-resistor1-leg1");
  await wire("term-part-resistor1-leg2", "term-uno-GND");
  await page.locator('[data-testid="tool-select"]').click();
}

const BLINK_BOTH_SKETCH = `
void setup() {
  pinMode(8, OUTPUT);
  pinMode(13, OUTPUT);
}
void loop() {
  digitalWrite(8, HIGH);
  digitalWrite(13, HIGH);
  delay(200);
}
`;

async function runSketch(page: Page, code: string) {
  const editor = page.getByPlaceholder(/Type or paste your Arduino C\+\+ sketch/);
  await editor.fill(code);
  await page.getByRole("button", { name: "Start Simulation" }).click();
}

/** Screenshot the full 1080px workbench (element shot ignores viewport clip). */
async function shotWorkbench(page: Page, path: string) {
  const wb = page.locator('[data-testid="arduino-workbench"]');
  await wb.scrollIntoViewIfNeeded();
  // reset the scrollable workbench container so the capture starts at x=0
  await wb.evaluate((el) => el.parentElement?.scrollTo({ left: 0 }));
  await page.waitForTimeout(400);
  await wb.screenshot({ path });
}

/** Collect browser console errors (page crashes, failed hydration, etc). */
function collectConsoleErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(`console.error: ${m.text()}`);
  });
  return errors;
}

describeRealDB("Arduino manual wiring (Tinkercad-style)", () => {
  // IT10 assessments are date-gated for production (Open Fri 2026-10-16
  // 08:00–10:00 Asia/Manila). The e2e DB is built from the same migrations, so
  // the worksheet under test would be unreachable ("not yet open"). Open the
  // IT10 window for the duration of the test run only — this is a test fixture,
  // not a change to the production window.
  test.beforeAll(async () => {
    const url = process.env["DATABASE_URL"];
    if (!url) return;
    const pool = new Pool({ connectionString: url });
    try {
      await pool.query(
        `UPDATE public.quizzes
            SET opens_at = NULL, closes_at = now() + interval '30 days'
          WHERE deleted_at IS NULL
            AND course_id = (SELECT id FROM public.courses WHERE code = 'IT10')`,
      );
    } finally {
      await pool.end();
    }
  });

  test("worksheet lab_task: manual wiring lights the wired LED, summary inserts", async ({
    page,
  }, testInfo) => {
    test.setTimeout(TEST_TIMEOUT);
    const errors = collectConsoleErrors(page);
    await page.goto("/dashboard/student/quizzes");
    await expect(page.getByRole("heading", { name: "Worksheets" })).toBeVisible({
      timeout: 20000,
    });

    // Open the Arduino Part 2 worksheet. Each attempt draws a random
    // 20-of-26 question subset in shuffled order, so retry a few times
    // until a lab_task question (Simulation Task A/B) is in the paper.
    const startBtn = page
      .locator("div")
      .filter({ hasText: "Quiz — Arduino Part 2" })
      .last()
      .getByRole("button", { name: /Start worksheet|Retake/ });

    let onLabTask = false;
    for (let attempt = 0; attempt < 5 && !onLabTask; attempt++) {
      if (attempt > 0) {
        await page.goto("/dashboard/student/quizzes");
        await expect(page.getByRole("heading", { name: "Worksheets" })).toBeVisible({
          timeout: 20000,
        });
      }
      // The quiz runner now persists the drawn question set per quiz so a reload
      // resumes the SAME questions. Clear it between attempts so each attempt
      // draws a fresh random subset (the point of this retry loop).
      await page.evaluate(() => {
        for (const k of Object.keys(localStorage)) {
          if (k.startsWith("miow_quiz_")) localStorage.removeItem(k);
        }
      });
      await startBtn.click();
      await dismissExamLock(page);

      // Scan the shuffled paper for the lab_task question
      const navCount = await page.locator('[data-testid^="question-nav-"]').count();
      for (let i = 1; i <= navCount; i++) {
        await page.getByTestId(`question-nav-${i}`).click();
        if (
          await page
            .locator('[data-testid="connections-summary"]')
            .isVisible()
            .catch(() => false)
        ) {
          onLabTask = true;
          break;
        }
      }
    }
    expect(onLabTask).toBe(true);
    await expect(page.getByText(/Simulation Task [AB]/)).toBeVisible({ timeout: 15000 });
    await dismissExamLock(page);

    // The lab panel + connections summary live in the question view
    await expect(page.locator('[data-testid="connections-summary"]')).toBeVisible();

    // Build the circuit MANUALLY — nothing is pre-wired (and no ghost guides
    // in the worksheet embed until the student wires terminals themselves)
    expect(await page.locator('[data-testid="ghost-guide"]').count()).toBe(0);
    expect(await page.locator('[data-testid^="part-"]').count()).toBe(0);
    await wireLedWithResistor(page);
    expect(await page.locator('[data-testid^="part-"]').count()).toBe(3);

    // Unwired LED2 exists too (placed above) — it must stay dark even on D13
    await runSketch(page, BLINK_BOTH_SKETCH);

    const led1 = page.locator('[data-testid="part-LED1"]');
    const led2 = page.locator('[data-testid="part-LED2"]');
    await expect(led1).toHaveAttribute("data-lit", "true", { timeout: 15000 });
    await expect(led2).toHaveAttribute("data-lit", "false", { timeout: 15000 });

    // Connections summary reflects the manual wires (grader-friendly wording)
    const summary = page.locator('[data-testid="connections-summary"]');
    await expect(summary).toContainText("LED1 anode", { timeout: 15000 });
    await expect(summary).toContainText("D8");
    await expect(summary).toContainText("GND");
    await expect(summary).toContainText("resistor");

    await page.screenshot({ path: "/tmp/opencode/ard-quiz-wired.png" });
    await shotWorkbench(page, "/tmp/opencode/ard-quiz-workbench.png");

    // One-click insert feeds the existing keyword grader
    await page.locator('[data-testid="insert-connections"]').click();
    await expect(page.locator('[data-testid="answer-input"]')).toHaveValue(/LED1 anode/);

    await page.screenshot({ path: "/tmp/opencode/ard-quiz-summary.png" });
    await shotWorkbench(page, "/tmp/opencode/ard-quiz-workbench-lit.png");
    await testInfo.attach("ard-quiz-summary", {
      path: "/tmp/opencode/ard-quiz-summary.png",
    });
    expect(errors).toEqual([]);
  });

  test("Arduino Lab route: same manual wiring + ghost guide chips", async ({ page }, testInfo) => {
    test.setTimeout(TEST_TIMEOUT);
    const errors = collectConsoleErrors(page);
    await page.goto("/dashboard/student/arduino");
    await expect(page.getByText("Arduino Uno Virtual Lab")).toBeVisible({ timeout: 20000 });

    // Manual wiring first — parts placed from the palette, wires by hand
    await wireLedWithResistor(page);
    await runSketch(page, BLINK_BOTH_SKETCH);
    await expect(page.locator('[data-testid="part-LED1"]')).toHaveAttribute("data-lit", "true", {
      timeout: 15000,
    });
    await expect(page.locator('[data-testid="part-LED2"]')).toHaveAttribute("data-lit", "false", {
      timeout: 15000,
    });
    await page.screenshot({ path: "/tmp/opencode/ard-lab-wired.png" });
    await shotWorkbench(page, "/tmp/opencode/ard-lab-workbench.png");

    // Seeded Part II task chips with a dashed ghost wiring guide (no solid wires)
    const chipA = page.locator('[data-testid="task-chip-traffic-light"]');
    const chipB = page.locator('[data-testid="task-chip-button-led"]');
    await expect(chipA).toBeVisible();
    await expect(chipB).toBeVisible();

    await chipA.click();
    await expect(page.locator('[data-testid="task-hint"]')).toBeVisible();
    const guides = page.locator('[data-testid="ghost-guide"]');
    expect(await guides.count()).toBeGreaterThan(0);
    // let React paint the seeded task parts before the screenshots
    await page.waitForTimeout(800);
    expect(await page.locator('[data-testid^="part-"]').count()).toBeGreaterThanOrEqual(9);

    await page.screenshot({ path: "/tmp/opencode/ard-lab-ghost-guide.png" });
    await shotWorkbench(page, "/tmp/opencode/ard-lab-ghost-workbench.png");

    // Ghost guide is dashed-only: the manual wires we placed are untouched
    await expect(page.locator('[data-testid="part-LED1"]')).toHaveAttribute("data-lit", "true", {
      timeout: 15000,
    });

    await chipB.click();
    await expect(page.locator('[data-testid="task-hint"]')).toContainText("Task B");
    await page.screenshot({ path: "/tmp/opencode/ard-lab-task-b.png" });
    await shotWorkbench(page, "/tmp/opencode/ard-lab-task-b-workbench.png");
    await testInfo.attach("ard-lab-ghost-guide", {
      path: "/tmp/opencode/ard-lab-ghost-guide.png",
    });
    expect(errors).toEqual([]);
  });

  test("unwired parts stay dark — no pre-placed jumpers", async ({ page }) => {
    test.setTimeout(TEST_TIMEOUT);
    const errors = collectConsoleErrors(page);
    await page.goto("/dashboard/student/arduino");
    await expect(page.getByText("Arduino Uno Virtual Lab")).toBeVisible({ timeout: 20000 });

    // Seed a task (which shows dashed ghost guides) and add a palette LED
    await page.locator('[data-testid="task-chip-traffic-light"]').click();
    await page.locator('[data-testid="palette-wokwi-led"]').click();

    // Run a sketch driving D13 HIGH — every unwired LED must stay dark
    await runSketch(page, BLINK_BOTH_SKETCH);
    await page.waitForTimeout(1500);
    const lit = page.locator('[data-testid="part-LED4"][data-lit="true"]');
    expect(await lit.count()).toBe(0);
    await expect(page.locator('[data-testid="part-LED1"]')).toHaveAttribute("data-lit", "false");
    expect(errors).toEqual([]);
  });
});
