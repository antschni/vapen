import { expect, test } from "@playwright/test";

test.describe("auth", () => {
  test("login page renders without tokens in HTML", async ({ page }) => {
    await page.goto("/login");
    await expect(
      page.getByRole("heading", { name: /anmelden/i }),
    ).toBeVisible();
    const html = await page.content();
    expect(html).not.toMatch(/vpr_[A-Za-z0-9_-]+/);
    expect(html).not.toMatch(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/);
  });
});
