import { test, expect } from '../fixtures/test-fixtures';

test.describe('Authentication', () => {
  test('home page loads without errors', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveTitle(/Game Platform/i);
  });

  test('guest login redirects to home', async ({ page, authPage }) => {
    await authPage.loginAsGuest();
    await expect(page).toHaveURL(/\/home/);
  });

  test('login page renders email and password fields', async ({ page }) => {
    await page.goto('/login');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('[data-testid="email-input"]')).toBeVisible();
    await expect(page.locator('[data-testid="password-input"]')).toBeVisible();
    await expect(page.locator('[data-testid="login-button"]')).toBeVisible();
  });

  test('sign up link is visible on login page', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('[data-testid="signup-link"]')).toBeVisible();
  });

  test('forgot password link is visible', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('[data-testid="forgot-password-link"]')).toBeVisible();
  });

  test('invalid credentials show error message', async ({ page }) => {
    await page.goto('/login');
    await page.waitForLoadState('networkidle');
    await page.fill('[data-testid="email-input"]', 'bad@example.com');
    await page.fill('[data-testid="password-input"]', 'wrongpassword');
    await page.click('[data-testid="login-button"]');
    await expect(page.locator('[data-testid="auth-error"]')).toBeVisible({ timeout: 5000 });
  });

  test('authenticated user can log out', async ({ authenticatedPage, authPage }) => {
    await authPage.logout();
    await expect(authenticatedPage).toHaveURL('/');
  });

  test('unauthenticated users are redirected from protected routes', async ({ page }) => {
    await page.goto('/home');
    // Should redirect to login or root
    await page.waitForURL(/(\/login|\/)/);
    const url = page.url();
    expect(url.endsWith('/home')).toBe(false);
  });
});
