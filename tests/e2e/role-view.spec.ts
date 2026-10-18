import { test, expect, type Page } from "@playwright/test";

async function signIn(page: Page) {
  await page.goto("/auth");
  // Desktop switches to RFID in an effect, so this also waits for hydration.
  await expect(page.getByRole("tab", { name: /RFID/ })).toHaveAttribute("aria-selected", "true");
  await page.getByRole("tab", { name: /PIN/ }).click();
  await page.getByLabel("Student ID, email, or username").fill("test@g.msuiit.edu.ph");
  await page.getByLabel("PIN or password", { exact: true }).fill("0916");
  await page.getByRole("button", { name: "Sign In", exact: true }).click();
  await expect(page).toHaveURL(/\/dashboard\//, { timeout: 30_000 });
}

test("test account switches cookie-backed role views and keeps them after reload", async ({
  page,
  context,
}) => {
  test.setTimeout(120_000);
  await signIn(page);
  const switcher = page.getByTestId("role-view-switcher").filter({ visible: true });
  await expect(switcher.getByRole("button", { name: "Teacher", exact: true })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
  const cookies = await context.cookies();
  expect(cookies.some((cookie) => cookie.name.endsWith("miow_session") && cookie.httpOnly)).toBe(
    true,
  );

  for (const [label, path] of [
    ["Admin", "/dashboard/admin"],
    ["Student", "/dashboard/student"],
    ["Teacher", "/dashboard/admin/courses"],
  ]) {
    await switcher.getByRole("button", { name: label, exact: true }).click();
    await expect(page).toHaveURL(new RegExp(`${path}$`));
    await expect(switcher.getByRole("button", { name: label, exact: true })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    await page.reload();
    await expect(switcher.getByRole("button", { name: label, exact: true })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
  }

  await switcher.getByRole("button", { name: "Student", exact: true }).click();
  await expect(page).toHaveURL(/\/dashboard\/student$/);
  await page
    .getByRole("button", { name: "Sign out", exact: true })
    .filter({ visible: true })
    .click();
  await signIn(page);
  await expect(switcher.getByRole("button", { name: "Teacher", exact: true })).toHaveAttribute(
    "aria-pressed",
    "true",
  );
});
