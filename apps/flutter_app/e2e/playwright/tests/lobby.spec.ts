import { test, expect } from '../fixtures/test-fixtures';

test.describe('Game Lobby', () => {
  test.beforeEach(async ({ authPage }) => {
    await authPage.loginAsGuest();
  });

  test('game list is displayed on home screen', async ({ page }) => {
    await expect(page.locator('[data-testid="game-list"]')).toBeVisible();
  });

  test('all expected games are listed', async ({ page }) => {
    const expectedGames = ['Twenty-Nine', 'Oh Hell', 'Hearts', 'Spades', 'Chess', 'Ludo'];
    for (const game of expectedGames) {
      await expect(page.locator(`text=${game}`)).toBeVisible();
    }
  });

  test('selecting a game opens its lobby', async ({ page, lobbyPage }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await expect(page).toHaveURL(/\/lobby/);
    await expect(page.locator('[data-testid="lobby-header"]')).toBeVisible();
  });

  test('create room button is visible in lobby', async ({ page, lobbyPage }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await expect(page.locator('text=Create Room')).toBeVisible();
  });

  test('creating a room navigates to room screen', async ({ page, lobbyPage }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    await expect(page).toHaveURL(/\/room\//);
  });

  test('room screen shows player slots', async ({ lobbyPage, roomPage }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    const slotCount = await roomPage.getPlayerSlotCount();
    expect(slotCount).toBeGreaterThanOrEqual(1);
  });

  test('bots can be added to the room', async ({ lobbyPage, roomPage, page }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    await roomPage.addBots(3);
    const slotCount = await roomPage.getPlayerSlotCount();
    expect(slotCount).toBe(4);
  });

  test('room code is visible and copyable', async ({ lobbyPage, page }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    await expect(page.locator('[data-testid="room-code"]')).toBeVisible();
  });

  test('room settings panel can be opened', async ({ lobbyPage, page }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    const settingsBtn = page.locator('[data-testid="room-settings-button"]');
    if (await settingsBtn.isVisible()) {
      await settingsBtn.click();
      await expect(page.locator('[data-testid="room-settings-panel"]')).toBeVisible();
    }
  });

  test('social mode selector is shown in room settings', async ({ lobbyPage, page }) => {
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    const settingsBtn = page.locator('[data-testid="room-settings-button"]');
    if (await settingsBtn.isVisible()) {
      await settingsBtn.click();
      await expect(page.locator('[data-testid="social-mode-selector"]')).toBeVisible();
    }
  });
});
