import { test, expect } from '@playwright/test';
import { customDevices, responsiveTestDevices } from '../utils/device-profiles';

test.describe('Responsive Design', () => {
  for (const deviceName of responsiveTestDevices) {
    const device = customDevices[deviceName];

    test.describe(`on ${deviceName}`, () => {
      test.use({
        viewport: device.viewport,
        isMobile: device.isMobile,
        hasTouch: device.hasTouch,
      });

      test('home screen renders correctly', async ({ page }) => {
        await page.goto('/');
        await page.waitForLoadState('networkidle');

        await expect(page.locator('[data-testid="game-list"]')).toBeVisible();

        await expect(page).toHaveScreenshot(`home-${deviceName}.png`, {
          fullPage: true,
          maxDiffPixelRatio: 0.02,
        });
      });

      test('game screen layout adapts correctly', async ({ page }) => {
        await page.goto('/game/test-room');
        await page.waitForLoadState('networkidle');

        await expect(page.locator('[data-testid="player-hand"]')).toBeVisible();
        await expect(page.locator('[data-testid="play-area"]')).toBeVisible();

        if (device.isMobile) {
          const cardBox = await page.locator('[data-testid="card"]').first().boundingBox();
          if (cardBox) {
            // Touch targets: cards must be at least 44 × 44 CSS px
            expect(cardBox.width).toBeGreaterThanOrEqual(44);
            expect(cardBox.height).toBeGreaterThanOrEqual(44);
          }
        }

        await expect(page).toHaveScreenshot(`game-${deviceName}.png`, { maxDiffPixelRatio: 0.02 });
      });

      test('chat panel works on device', async ({ page }) => {
        await page.goto('/game/test-room');
        await page.waitForLoadState('networkidle');

        await page.click('[data-testid="chat-toggle"]');
        await expect(page.locator('[data-testid="chat-panel"]')).toBeVisible();

        await page.fill('[data-testid="chat-input"]', 'Hello!');
        await page.click('[data-testid="chat-send"]');

        await expect(page.locator('text=Hello!')).toBeVisible({ timeout: 5_000 });

        await expect(page).toHaveScreenshot(`chat-${deviceName}.png`, { maxDiffPixelRatio: 0.02 });
      });

      test('navigation is accessible', async ({ page }) => {
        await page.goto('/');
        await page.waitForLoadState('networkidle');

        if (device.isMobile) {
          const hamburger = page.locator('[data-testid="menu-toggle"]');
          if (await hamburger.isVisible()) {
            await hamburger.click();
            await expect(page.locator('[data-testid="nav-menu"]')).toBeVisible();
          }

          // Bottom navigation should exist on mobile
          const bottomNav = page.locator('[data-testid="bottom-nav"]');
          await expect(bottomNav).toBeVisible();
        } else {
          // Side or top nav on desktop
          await expect(page.locator('[data-testid="main-nav"]')).toBeVisible();
        }
      });
    });
  }
});

test.describe('Orientation Changes', () => {
  test('game adapts to landscape on tablet', async ({ page }) => {
    // Portrait
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/game/test-room');
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot('game-tablet-portrait.png', { maxDiffPixelRatio: 0.02 });

    // Landscape
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.waitForTimeout(500); // allow layout reflow
    await expect(page).toHaveScreenshot('game-tablet-landscape.png', { maxDiffPixelRatio: 0.02 });

    const playArea = await page.locator('[data-testid="play-area"]').boundingBox();
    if (playArea) {
      expect(playArea.width).toBeGreaterThan(playArea.height);
    }
  });
});

test.describe('Touch Interactions', () => {
  test.use({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
  });

  test('cards can be selected with tap', async ({ page }) => {
    await page.goto('/game/test-room');
    await page.waitForLoadState('networkidle');

    const card = page.locator('[data-testid="card"]').first();
    await card.tap();
    await expect(card).toHaveAttribute('data-selected', 'true');
  });

  test('swipe left on game carousel advances to next game', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const carousel = page.locator('[data-testid="game-carousel"]');
    if (await carousel.isVisible()) {
      // Simulate swipe left via touch events
      await carousel.evaluate((el) => {
        el.dispatchEvent(
          new TouchEvent('touchstart', {
            touches: [{ clientX: 300, clientY: 200 } as Touch],
            bubbles: true,
          })
        );
        el.dispatchEvent(
          new TouchEvent('touchend', {
            changedTouches: [{ clientX: 100, clientY: 200 } as Touch],
            bubbles: true,
          })
        );
      });
      // Verify by screenshot — exact assertion depends on implementation
      await expect(page).toHaveScreenshot('carousel-after-swipe.png', { maxDiffPixelRatio: 0.03 });
    }
  });
});
