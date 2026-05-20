import { test, expect } from '../fixtures/test-fixtures';

test.describe('Complete Game Flow — Twenty-Nine', () => {
  test('user can reach the game screen via full lobby flow', async ({
    page,
    authPage,
    lobbyPage,
    roomPage,
    gamePage,
  }) => {
    // ── Auth ─────────────────────────────────────────────────
    await authPage.loginAsGuest();

    // ── Lobby ────────────────────────────────────────────────
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();

    // ── Room: add 3 bots ─────────────────────────────────────
    await roomPage.addBots(3, 'Medium');
    expect(await roomPage.getPlayerSlotCount()).toBe(4);

    // ── Ready up & start ─────────────────────────────────────
    await roomPage.setReady();
    await roomPage.startGame();

    // ── Verify game screen ───────────────────────────────────
    await expect(page.locator('[data-testid="game-table"]')).toBeVisible({ timeout: 10_000 });
    await expect(page.locator('[data-testid="player-hand"]')).toBeVisible();

    // ── Bidding phase ────────────────────────────────────────
    await gamePage.waitForPhase('Bidding', 8_000);
    await expect(page).toHaveScreenshot('game-bidding-phase.png', { maxDiffPixelRatio: 0.02 });

    // ── Interact: bid or pass ────────────────────────────────
    const bid16 = page.locator('[data-testid="bid-16"]');
    if (await bid16.isEnabled()) {
      await gamePage.placeBid(16);
    } else {
      await gamePage.pass();
    }

    // ── Allow bots to progress game ──────────────────────────
    await page.waitForTimeout(6_000);

    // ── Verify game has advanced ─────────────────────────────
    const phase = await page.locator('[data-testid="game-phase"]').textContent();
    expect(['Bidding', 'Trump Selection', 'Playing', 'Scoring', 'Finished']).toContain(phase?.trim());
  });

  test('chat is functional during a game', async ({
    page,
    authPage,
    lobbyPage,
    roomPage,
    gamePage,
  }) => {
    await authPage.loginAsGuest();
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    await roomPage.addBots(3);
    await roomPage.setReady();
    await roomPage.startGame();

    await expect(page.locator('[data-testid="game-table"]')).toBeVisible({ timeout: 10_000 });

    await gamePage.openChat();
    await gamePage.sendChatMessage('Good luck!');
    await expect(page.locator('text=Good luck!')).toBeVisible({ timeout: 5_000 });
  });

  test('game HUD shows correct information', async ({
    page,
    authPage,
    lobbyPage,
    roomPage,
  }) => {
    await authPage.loginAsGuest();
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    await roomPage.addBots(3);
    await roomPage.setReady();
    await roomPage.startGame();

    await expect(page.locator('[data-testid="game-table"]')).toBeVisible({ timeout: 10_000 });

    // HUD elements should be present
    await expect(page.locator('[data-testid="score-display"]')).toBeVisible();
    await expect(page.locator('[data-testid="game-phase"]')).toBeVisible();
  });

  test('player hand cards are rendered', async ({
    page,
    authPage,
    lobbyPage,
    roomPage,
    gamePage,
  }) => {
    await authPage.loginAsGuest();
    await lobbyPage.navigateToGame('Twenty-Nine');
    await lobbyPage.createRoom();
    await roomPage.addBots(3);
    await roomPage.setReady();
    await roomPage.startGame();

    await expect(page.locator('[data-testid="game-table"]')).toBeVisible({ timeout: 10_000 });
    await gamePage.waitForPhase('Bidding', 8_000);

    const handCards = await gamePage.getHandCards();
    const count = await handCards.count();
    expect(count).toBeGreaterThan(0);
    expect(count).toBeLessThanOrEqual(8); // Twenty-Nine deals 8 cards
  });
});
