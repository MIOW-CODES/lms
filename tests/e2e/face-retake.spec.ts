import { test, expect, type Page } from "@playwright/test";

// ── Helpers (mirror tests/e2e/user-flows.spec.ts) ────────────
const SESSION_KEY = "northview-lms-session";

function fakeStudentProfile() {
  return {
    id: "test-student-001",
    student_id: "2024-0001",
    email: "student@test.miow",
    pin: null,
    full_name: "Test Student",
    role: "student",
    rfid_uid: null,
    avatar_url: null,
    face_embedding: null,
    grade_level: 10,
    section: "A",
    created_at: new Date().toISOString(),
    employee_id: null,
    department: null,
    biometric_enrolled_at: null,
    has_pin: true,
    has_rfid: false,
    session_token: "test-session-token",
  };
}

async function seedSession(page: Page) {
  await page.goto("/");
  await page.evaluate(
    ({ key, profile }: { key: string; profile: ReturnType<typeof fakeStudentProfile> }) => {
      localStorage.setItem(key, JSON.stringify(profile));
    },
    { key: SESSION_KEY, profile: fakeStudentProfile() },
  );
}

// ══════════════════════════════════════════════════════════
// STUDENT FACE RETAKE — NO-CAMERA PATH
// ══════════════════════════════════════════════════════════
test.describe("Student face retake", () => {
  test.beforeEach(async ({ page }) => {
    // Deny webcam before any page script runs so the retake path is
    // deterministic in both headless CI and headed local runs.
    await page.addInitScript(() => {
      try {
        Object.defineProperty(navigator, "mediaDevices", {
          value: {
            getUserMedia: () =>
              Promise.reject(new DOMException("Permission denied", "NotAllowedError")),
          },
          configurable: true,
        });
      } catch {
        // Navigator shape is platform-controlled; the video element still
        // yields no descriptor without a stream, so the test stays valid.
      }
    });
    await seedSession(page);
  });

  test("no-camera capture shows the error toast and never the success toast", async ({ page }) => {
    await page.goto("/dashboard/student/settings");
    await page.getByRole("button", { name: /Hardware & Security/ }).click();
    await page.getByRole("button", { name: /Retake face snapshot/ }).click();
    await expect(page.getByText("Retake Face Snapshot")).toBeVisible({ timeout: 10000 });

    await page.getByRole("button", { name: /Capture/ }).click();

    // No-camera path: descriptor is null → error toast, no audit/success UI.
    await expect(
      page.getByText("Camera not ready — allow webcam access and try again"),
    ).toBeVisible({ timeout: 30000 });
    await expect(page.getByText("Facial profile updated")).toHaveCount(0);
    // Modal stays open on failure (it only closes on success).
    await expect(page.getByText("Retake Face Snapshot")).toBeVisible();
  });
});
