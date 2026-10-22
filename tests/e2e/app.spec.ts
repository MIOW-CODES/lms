import { test, expect } from "@playwright/test";

test.describe("MIOW – public routes (MIOW retained)", () => {
  test("homepage loads with MIOW brand and no Lovable", async ({ page }) => {
    await page.goto("/");
    // Title should contain MIOW
    await expect(page).toHaveTitle(/MIOW/);
    // Should not contain Lovable
    const body = await page.content();
    expect(body.toLowerCase()).not.toContain("lovable");
    // Should have MIOW visible
    await expect(page.locator("body")).toContainText("MIOW");
  });

  test("auth page loads", async ({ page }) => {
    await page.goto("/auth");
    await expect(page).toHaveTitle(/MIOW/);
    // Should have sign-in UI (PIN / RFID)
    const body = await page.content();
    // auth page has Kiosk / Sign in text
    expect(body.length).toBeGreaterThan(500);
    expect(body.toLowerCase()).not.toContain("lovable");
  });

  test("sitemap is not published", async ({ request }) => {
    const res = await request.get("/sitemap.xml");
    expect(res.status()).toBe(404);
  });

  test("404 page works", async ({ page }) => {
    await page.goto("/this-route-does-not-exist-xyz");
    await expect(page.locator("body")).toContainText("404");
  });
});
