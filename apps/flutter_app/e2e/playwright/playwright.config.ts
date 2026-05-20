import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['json', { outputFile: 'test-results.json' }],
    ['list'],
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    // ── Desktop Browsers ──────────────────────────────────────
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    // ── Mobile Phones ─────────────────────────────────────────
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    },
    {
      name: 'Mobile Safari Mini',
      use: { ...devices['iPhone SE'] },
    },

    // ── Tablets ───────────────────────────────────────────────
    {
      name: 'iPad',
      use: { ...devices['iPad Pro 11'] },
    },
    {
      name: 'iPad Landscape',
      use: { ...devices['iPad Pro 11 landscape'] },
    },

    // ── Large / Wide Screens ──────────────────────────────────
    {
      name: '4K Display',
      use: {
        viewport: { width: 3840, height: 2160 },
        deviceScaleFactor: 2,
      },
    },
    {
      name: 'Ultrawide',
      use: {
        viewport: { width: 3440, height: 1440 },
      },
    },
  ],

  webServer: {
    command: 'flutter run -d chrome --web-port=3000',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
