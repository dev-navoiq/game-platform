import { test as base, expect, Page } from '@playwright/test';

// ── Shared test data ─────────────────────────────────────────────────────────

export const TEST_USER = {
  email: 'test@gameplatform.dev',
  password: 'TestPass123!',
  displayName: 'TestPlayer',
};

export const GUEST_LABEL = 'Continue as Guest';

// ── Page-Object helpers ──────────────────────────────────────────────────────

export class AuthPage {
  constructor(private page: Page) {}

  async loginAsGuest() {
    await this.page.goto('/');
    await this.page.waitForLoadState('networkidle');
    await this.page.click(`text=${GUEST_LABEL}`);
    await this.page.waitForURL('**/home');
  }

  async loginWithCredentials(email: string, password: string) {
    await this.page.goto('/login');
    await this.page.waitForLoadState('networkidle');
    await this.page.fill('[data-testid="email-input"]', email);
    await this.page.fill('[data-testid="password-input"]', password);
    await this.page.click('[data-testid="login-button"]');
    await this.page.waitForURL('**/home');
  }

  async logout() {
    await this.page.click('[data-testid="profile-menu"]');
    await this.page.click('[data-testid="logout-button"]');
    await this.page.waitForURL('/');
  }
}

export class LobbyPage {
  constructor(private page: Page) {}

  async navigateToGame(gameName: string) {
    await this.page.click(`text=${gameName}`);
    await this.page.waitForURL('**/lobby**');
  }

  async createRoom() {
    await this.page.click('text=Create Room');
    await this.page.waitForURL('**/room/**');
  }

  async joinRoom(roomCode: string) {
    await this.page.fill('[data-testid="room-code-input"]', roomCode);
    await this.page.click('[data-testid="join-room-button"]');
    await this.page.waitForURL('**/room/**');
  }
}

export class RoomPage {
  constructor(private page: Page) {}

  async addBots(count: number, difficulty: 'Easy' | 'Medium' | 'Hard' = 'Medium') {
    for (let i = 0; i < count; i++) {
      await this.page.click('text=Add Bot');
      await this.page.click(`text=${difficulty}`);
    }
  }

  async setReady() {
    await this.page.click('text=Ready');
  }

  async startGame() {
    await this.page.click('text=Start Game');
    await this.page.waitForURL('**/game/**');
  }

  async getPlayerSlotCount(): Promise<number> {
    return this.page.locator('[data-testid="player-slot"]').count();
  }
}

export class GamePage {
  constructor(private page: Page) {}

  async waitForPhase(phase: string, timeout = 10_000) {
    await expect(this.page.locator(`text=${phase}`)).toBeVisible({ timeout });
  }

  async getHandCards() {
    return this.page.locator('[data-testid="player-hand"] [data-testid="card"]');
  }

  async playCard(index = 0) {
    const cards = await this.getHandCards();
    await cards.nth(index).click();
  }

  async placeBid(value: number) {
    await this.page.click(`[data-testid="bid-${value}"]`);
  }

  async pass() {
    await this.page.click('[data-testid="pass-button"]');
  }

  async openChat() {
    await this.page.click('[data-testid="chat-toggle"]');
    await expect(this.page.locator('[data-testid="chat-panel"]')).toBeVisible();
  }

  async sendChatMessage(text: string) {
    await this.page.fill('[data-testid="chat-input"]', text);
    await this.page.click('[data-testid="chat-send"]');
  }
}

// ── Custom fixture type ──────────────────────────────────────────────────────

type Fixtures = {
  authPage: AuthPage;
  lobbyPage: LobbyPage;
  roomPage: RoomPage;
  gamePage: GamePage;
  /** Logs in as guest and returns to home before the test body runs. */
  authenticatedPage: Page;
};

export const test = base.extend<Fixtures>({
  authPage: async ({ page }, use) => {
    await use(new AuthPage(page));
  },

  lobbyPage: async ({ page }, use) => {
    await use(new LobbyPage(page));
  },

  roomPage: async ({ page }, use) => {
    await use(new RoomPage(page));
  },

  gamePage: async ({ page }, use) => {
    await use(new GamePage(page));
  },

  authenticatedPage: async ({ page }, use) => {
    const auth = new AuthPage(page);
    await auth.loginAsGuest();
    await use(page);
  },
});

export { expect };
