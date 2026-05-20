# 05 - Testing Strategy

> Establish a comprehensive testing strategy covering unit tests, widget tests, integration tests, and cross-device UI/UX testing with Playwright.

## Philosophy: Test-First Development

**Write tests BEFORE implementation** for:
- Game rules and logic
- State management
- Critical user flows
- Edge cases in gameplay

This ensures the game logic is bulletproof before building UI on top.

---

## Testing Pyramid

```
                    ┌─────────────────┐
                    │   E2E Tests     │  ← Playwright (cross-browser, cross-device)
                    │   (Few, Slow)   │
                   ─┴─────────────────┴─
                  ┌───────────────────────┐
                  │   Integration Tests   │  ← Flutter integration_test
                  │   (Some, Medium)      │
                 ─┴───────────────────────┴─
                ┌───────────────────────────────┐
                │       Widget Tests            │  ← Flutter test + golden tests
                │       (Many, Fast)            │
               ─┴───────────────────────────────┴─
              ┌───────────────────────────────────────┐
              │           Unit Tests                  │  ← Pure Dart tests
              │           (Most, Fastest)             │
              └───────────────────────────────────────┘
```

---

## Directory Structure

```
packages/
├── game_core/
│   └── test/
│       ├── cards/
│       │   ├── playing_card_test.dart
│       │   ├── deck_test.dart
│       │   └── hand_test.dart
│       ├── board/
│       │   └── board_position_test.dart
│       └── registry/
│           └── game_registry_test.dart
├── game_twenty_nine/
│   └── test/
│       ├── twenty_nine_rules_test.dart
│       ├── twenty_nine_state_test.dart
│       ├── twenty_nine_moves_test.dart
│       ├── twenty_nine_scoring_test.dart
│       └── integration/
│           └── full_game_flow_test.dart
├── bot_strategies/
│   └── test/
│       └── twenty_nine_bot_test.dart

apps/flutter_app/
├── test/
│   ├── unit/
│   │   ├── providers/
│   │   │   ├── room_provider_test.dart
│   │   │   └── game_provider_test.dart
│   │   └── services/
│   │       ├── chat_service_test.dart
│   │       └── subscription_service_test.dart
│   ├── widget/
│   │   ├── playing_card_widget_test.dart
│   │   ├── glass_button_test.dart
│   │   ├── game_screen_test.dart
│   │   └── goldens/
│   │       ├── playing_card_golden_test.dart
│   │       └── game_screen_golden_test.dart
│   └── integration/
│       ├── login_flow_test.dart
│       ├── room_creation_test.dart
│       └── game_flow_test.dart
├── integration_test/
│   ├── app_test.dart
│   ├── game_twenty_nine_test.dart
│   └── purchase_flow_test.dart
└── e2e/
    └── playwright/
        ├── playwright.config.ts
        ├── tests/
        │   ├── auth.spec.ts
        │   ├── lobby.spec.ts
        │   ├── game-flow.spec.ts
        │   ├── responsive.spec.ts
        │   └── accessibility.spec.ts
        ├── fixtures/
        │   └── test-fixtures.ts
        └── utils/
            └── device-profiles.ts
```

---

## 1. Unit Tests (Game Logic)

### Game Rules Test Template

```dart
// packages/game_twenty_nine/test/twenty_nine_rules_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

void main() {
  late TwentyNineRules rules;
  late TwentyNineState initialState;
  final playerIds = ['p1', 'p2', 'p3', 'p4'];

  setUp(() {
    rules = TwentyNineRules();
    initialState = rules.createInitialState(
      playerIds: playerIds,
      dealerIndex: 0,
    );
  });

  group('Initial State', () {
    test('should create state with correct phase', () {
      expect(initialState.phase, GamePhase.bidding);
    });

    test('should deal 8 cards to each player', () {
      for (final playerId in playerIds) {
        expect(initialState.hands[playerId]?.size, 8);
      }
    });

    test('should set first bidder as player left of dealer', () {
      expect(initialState.currentPlayerId, 'p2');
    });

    test('should have no trump declared', () {
      expect(initialState.trumpSuit, isNull);
      expect(initialState.trumpRevealed, isFalse);
    });
  });

  group('Bidding Phase', () {
    test('should accept valid bid within range', () {
      final move = BidMove(playerId: 'p2', bidValue: 16);
      final error = rules.validateMove(initialState, move);
      expect(error, isNull);
    });

    test('should reject bid below minimum', () {
      final move = BidMove(playerId: 'p2', bidValue: 14);
      final error = rules.validateMove(initialState, move);
      expect(error, 'BID_TOO_LOW');
    });

    test('should reject bid above maximum (except 29)', () {
      final move = BidMove(playerId: 'p2', bidValue: 30);
      final error = rules.validateMove(initialState, move);
      expect(error, 'BID_TOO_HIGH');
    });

    test('should accept special 29 bid', () {
      final move = BidMove(playerId: 'p2', bidValue: 29);
      final error = rules.validateMove(initialState, move);
      expect(error, isNull);
    });

    test('should reject move from wrong player', () {
      final move = BidMove(playerId: 'p1', bidValue: 16);
      final error = rules.validateMove(initialState, move);
      expect(error, 'NOT_YOUR_TURN');
    });

    test('should advance to next player after bid', () {
      final move = BidMove(playerId: 'p2', bidValue: 16);
      final result = rules.applyMove(initialState, move);

      expect(result.isValid, isTrue);
      expect(result.newState.currentPlayerId, 'p3');
      expect(result.newState.currentBid, 16);
      expect(result.newState.bidderId, 'p2');
    });

    test('should transition to trump selection after 3 passes with bid', () {
      var state = initialState;

      // p2 bids
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 16)).newState;
      // p3, p4, p1 pass
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;

      expect(state.phase, GamePhase.trumpSelection);
      expect(state.bidderId, 'p2');
      // Trump selector is partner of bidder (p4)
      expect(state.trumpSelector, 'p4');
    });
  });

  group('Trump Selection Phase', () {
    late TwentyNineState trumpSelectionState;

    setUp(() {
      // Setup state at trump selection phase
      var state = initialState;
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 16)).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;
      trumpSelectionState = state;
    });

    test('should only allow trump selector to declare', () {
      // p4 is trump selector
      final invalidMove = DeclareTrumpMove(playerId: 'p2', suit: Suit.hearts);
      expect(rules.validateMove(trumpSelectionState, invalidMove), isNotNull);

      // Need to check if p4 has hearts in hand first
      final hand = trumpSelectionState.hands['p4']!;
      final validSuit = hand.cards.first.suit;
      final validMove = DeclareTrumpMove(playerId: 'p4', suit: validSuit);
      expect(rules.validateMove(trumpSelectionState, validMove), isNull);
    });

    test('should require trump selector to have cards of declared suit', () {
      // Find a suit the player doesn't have
      final hand = trumpSelectionState.hands['p4']!;
      final suits = hand.cards.map((c) => c.suit).toSet();
      final missingSuit = Suit.values.firstWhere(
        (s) => !suits.contains(s),
        orElse: () => Suit.hearts,
      );

      if (!suits.contains(missingSuit)) {
        final move = DeclareTrumpMove(playerId: 'p4', suit: missingSuit);
        expect(rules.validateMove(trumpSelectionState, move), 'NO_CARDS_OF_SUIT');
      }
    });
  });

  group('Playing Phase', () {
    late TwentyNineState playingState;

    setUp(() {
      // Create a state at playing phase with known hands
      playingState = TwentyNineState(
        phase: GamePhase.playing,
        currentPlayerId: 'p1',
        hands: {
          'p1': Hand([
            PlayingCard(Suit.hearts, Rank.ace),
            PlayingCard(Suit.hearts, Rank.king),
            PlayingCard(Suit.spades, Rank.jack),
          ]),
          'p2': Hand([
            PlayingCard(Suit.hearts, Rank.queen),
            PlayingCard(Suit.diamonds, Rank.nine),
          ]),
          'p3': Hand([
            PlayingCard(Suit.clubs, Rank.ten),
            PlayingCard(Suit.diamonds, Rank.jack),
          ]),
          'p4': Hand([
            PlayingCard(Suit.hearts, Rank.nine),
            PlayingCard(Suit.spades, Rank.ace),
          ]),
        },
        currentTrick: [],
        trumpSuit: Suit.spades,
        trumpRevealed: false,
        currentBid: 16,
        bidderId: 'p2',
        trumpSelector: 'p4',
        dealerIndex: 0,
        playerOrder: playerIds,
      );
    });

    test('should allow playing any card when leading', () {
      final move = PlayCardMove(
        playerId: 'p1',
        card: PlayingCard(Suit.spades, Rank.jack),
      );
      expect(rules.validateMove(playingState, move), isNull);
    });

    test('should require following suit when possible', () {
      // p1 leads hearts
      var state = rules.applyMove(
        playingState,
        PlayCardMove(playerId: 'p1', card: PlayingCard(Suit.hearts, Rank.ace)),
      ).newState;

      // p2 has hearts, must follow
      final invalidMove = PlayCardMove(
        playerId: 'p2',
        card: PlayingCard(Suit.diamonds, Rank.nine),
      );
      expect(rules.validateMove(state, invalidMove), 'MUST_FOLLOW_SUIT');

      // Valid: follow with hearts
      final validMove = PlayCardMove(
        playerId: 'p2',
        card: PlayingCard(Suit.hearts, Rank.queen),
      );
      expect(rules.validateMove(state, validMove), isNull);
    });

    test('should allow any card when cannot follow suit', () {
      // p1 leads hearts
      var state = rules.applyMove(
        playingState,
        PlayCardMove(playerId: 'p1', card: PlayingCard(Suit.hearts, Rank.ace)),
      ).newState;

      // Skip to p3 (who has no hearts)
      state = rules.applyMove(
        state,
        PlayCardMove(playerId: 'p2', card: PlayingCard(Suit.hearts, Rank.queen)),
      ).newState;

      // p3 has no hearts, can play anything
      final move = PlayCardMove(
        playerId: 'p3',
        card: PlayingCard(Suit.clubs, Rank.ten),
      );
      expect(rules.validateMove(state, move), isNull);
    });

    test('should determine correct trick winner with trump', () {
      var state = playingState;

      // p1 leads hearts A
      state = rules.applyMove(
        state,
        PlayCardMove(playerId: 'p1', card: PlayingCard(Suit.hearts, Rank.ace)),
      ).newState;

      // p2 follows with hearts Q
      state = rules.applyMove(
        state,
        PlayCardMove(playerId: 'p2', card: PlayingCard(Suit.hearts, Rank.queen)),
      ).newState;

      // p3 can't follow, plays club
      state = rules.applyMove(
        state,
        PlayCardMove(playerId: 'p3', card: PlayingCard(Suit.clubs, Rank.ten)),
      ).newState;

      // p4 follows with hearts 9
      final result = rules.applyMove(
        state,
        PlayCardMove(playerId: 'p4', card: PlayingCard(Suit.hearts, Rank.nine)),
      );

      // p1 should win with highest hearts (A)
      // But in 29, card strength is J>9>A>10>K>Q>8>7
      // So 9 beats A... let's verify
      expect(result.newState.currentTrick, isEmpty); // Trick collected
      // Winner leads next, check who
    });
  });

  group('Scoring', () {
    test('should calculate correct points for cards', () {
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.hearts, Rank.jack)), 3);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.spades, Rank.nine)), 2);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.clubs, Rank.ace)), 1);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.diamonds, Rank.ten)), 1);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.hearts, Rank.king)), 0);
    });

    test('total points in deck should be 28', () {
      final deck = Deck.standard32();
      var totalPoints = 0;
      while (deck.remaining > 0) {
        final card = deck.draw()!;
        totalPoints += TwentyNineConfig.getCardPoints(card);
      }
      expect(totalPoints, 28);
    });
  });

  group('Game End', () {
    test('should end game when team reaches 6 points', () {
      final state = TwentyNineState(
        phase: GamePhase.roundEnd,
        sessionScores: {0: 6, 1: 4},
        hands: {},
        dealerIndex: 0,
        playerOrder: playerIds,
      );

      expect(rules.isGameOver(state.copyWith(phase: GamePhase.gameEnd)), isTrue);
      expect(rules.getWinners(state.copyWith(
        phase: GamePhase.gameEnd,
        sessionScores: {0: 6, 1: 4},
      )), containsAll(['p1', 'p3'])); // Team 0
    });
  });

  group('Edge Cases', () {
    test('should handle all players passing with no bid (redeal)', () {
      var state = initialState;
      state = rules.applyMove(state, PassMove(playerId: 'p2')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;

      expect(state.allPlayersPassed, isTrue);
      // Should trigger redeal logic
    });

    test('should handle 29 special bid correctly', () {
      var state = initialState;
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 29)).newState;

      expect(state.currentBid, 29);
      // 29 bid has special rules (no trump reveal allowed)
    });
  });
}
```

### Card Primitives Tests

```dart
// packages/game_core/test/cards/deck_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

void main() {
  group('Deck', () {
    test('standard52 should have 52 cards', () {
      final deck = Deck.standard52();
      expect(deck.remaining, 52);
    });

    test('standard32 should have 32 cards (7 and up)', () {
      final deck = Deck.standard32();
      expect(deck.remaining, 32);

      // Verify no cards below 7
      while (deck.remaining > 0) {
        final card = deck.draw()!;
        expect(card.rank.index, greaterThanOrEqualTo(Rank.seven.index));
      }
    });

    test('shuffle should randomize order', () {
      final deck1 = Deck.standard52();
      final deck2 = Deck.standard52();

      deck1.shuffle();

      // Compare first 10 cards - statistically very unlikely to be same
      var sameCount = 0;
      for (var i = 0; i < 10; i++) {
        if (deck1.draw() == deck2.draw()) sameCount++;
      }
      expect(sameCount, lessThan(10));
    });

    test('draw should remove card from deck', () {
      final deck = Deck.standard52();
      final initialCount = deck.remaining;

      final card = deck.draw();

      expect(card, isNotNull);
      expect(deck.remaining, initialCount - 1);
    });

    test('draw from empty deck should return null', () {
      final deck = Deck.standard32();

      // Draw all cards
      while (deck.remaining > 0) {
        deck.draw();
      }

      expect(deck.draw(), isNull);
    });
  });

  group('Hand', () {
    test('hasSuit should return true when suit exists', () {
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.spades, Rank.king),
      ]);

      expect(hand.hasSuit(Suit.hearts), isTrue);
      expect(hand.hasSuit(Suit.diamonds), isFalse);
    });

    test('cardsOfSuit should return correct cards', () {
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.hearts, Rank.king),
        PlayingCard(Suit.spades, Rank.jack),
      ]);

      final hearts = hand.cardsOfSuit(Suit.hearts);
      expect(hearts.length, 2);
      expect(hearts.every((c) => c.suit == Suit.hearts), isTrue);
    });

    test('remove should remove specific card', () {
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.spades, Rank.king),
      ]);

      final removed = hand.remove(PlayingCard(Suit.hearts, Rank.ace));

      expect(removed, isTrue);
      expect(hand.size, 1);
      expect(hand.contains(PlayingCard(Suit.hearts, Rank.ace)), isFalse);
    });
  });
}
```

---

## 2. Widget Tests

### Golden Tests for Visual Regression

```dart
// test/widget/goldens/playing_card_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_app/shared/widgets/playing_card.dart';

void main() {
  group('PlayingCard Golden Tests', () {
    testGoldens('card faces render correctly', (tester) async {
      final builder = GoldenBuilder.grid(
        columns: 4,
        widthToHeightRatio: 0.66,
      )
        ..addScenario('Ace of Hearts', PlayingCardWidget(suit: 'hearts', rank: 'A'))
        ..addScenario('King of Spades', PlayingCardWidget(suit: 'spades', rank: 'K'))
        ..addScenario('Queen of Diamonds', PlayingCardWidget(suit: 'diamonds', rank: 'Q'))
        ..addScenario('Jack of Clubs', PlayingCardWidget(suit: 'clubs', rank: 'J'))
        ..addScenario('Ten of Hearts', PlayingCardWidget(suit: 'hearts', rank: '10'))
        ..addScenario('Card Back', PlayingCardWidget(suit: 'hearts', rank: 'A', isFaceDown: true))
        ..addScenario('Selected Card', PlayingCardWidget(suit: 'spades', rank: 'A', isSelected: true))
        ..addScenario('Disabled Card', PlayingCardWidget(suit: 'clubs', rank: '7', isPlayable: false));

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(800, 600),
      );

      await screenMatchesGolden(tester, 'playing_cards_grid');
    });

    testGoldens('card skins render correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario('Classic Skin', PlayingCardWidget(suit: 'hearts', rank: 'A', skinId: 'classic'))
        ..addScenario('Modern Skin', PlayingCardWidget(suit: 'hearts', rank: 'A', skinId: 'modern'))
        ..addScenario('Neon Skin', PlayingCardWidget(suit: 'hearts', rank: 'A', skinId: 'neon'));

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(300, 600),
      );

      await screenMatchesGolden(tester, 'card_skins');
    });
  });
}
```

### Responsive Widget Tests

```dart
// test/widget/responsive_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  group('Responsive Layout Tests', () {
    final devices = [
      Device.phone,
      Device.iphone11,
      Device.tabletPortrait,
      Device.tabletLandscape,
    ];

    testGoldens('game screen adapts to screen sizes', (tester) async {
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices)
        ..addScenario(
          widget: const GameScreen(roomId: 'test'),
          name: 'game_screen',
        );

      await tester.pumpDeviceBuilder(builder);
      await screenMatchesGolden(tester, 'game_screen_responsive');
    });

    testGoldens('lobby screen adapts to screen sizes', (tester) async {
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices)
        ..addScenario(
          widget: const LobbyScreen(),
          name: 'lobby_screen',
        );

      await tester.pumpDeviceBuilder(builder);
      await screenMatchesGolden(tester, 'lobby_screen_responsive');
    });
  });
}
```

---

## 3. Integration Tests (Flutter)

```dart
// integration_test/game_twenty_nine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Twenty-Nine Game Flow', () {
    testWidgets('complete game flow with bots', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // Select Twenty-Nine
      await tester.tap(find.text('Twenty-Nine'));
      await tester.pumpAndSettle();

      // Create room
      await tester.tap(find.text('Create Room'));
      await tester.pumpAndSettle();

      // Add bots
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Add Bot'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Medium'));
        await tester.pumpAndSettle();
      }

      // Ready up
      await tester.tap(find.text('Ready'));
      await tester.pumpAndSettle();

      // Start game
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify game screen loaded
      expect(find.byType(GameScreen), findsOneWidget);

      // Wait for bidding phase
      expect(find.text('Bidding'), findsOneWidget);

      // Place a bid
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();

      // Game continues with bots...
      // Wait for game to progress
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify game is progressing
      expect(find.byType(PlayingCardWidget), findsWidgets);
    });
  });
}
```

---

## 4. E2E Tests with Playwright

### Configuration

```typescript
// e2e/playwright/playwright.config.ts

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
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    // Desktop browsers
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

    // Mobile devices
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

    // Tablets
    {
      name: 'iPad',
      use: { ...devices['iPad Pro 11'] },
    },
    {
      name: 'iPad Landscape',
      use: {
        ...devices['iPad Pro 11 landscape'],
      },
    },

    // Large screens
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
    timeout: 120000,
  },
});
```

### Device Profiles

```typescript
// e2e/playwright/utils/device-profiles.ts

export const customDevices = {
  // Small phones
  'iPhone SE': {
    viewport: { width: 375, height: 667 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },

  // Medium phones
  'iPhone 12': {
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  // Large phones
  'iPhone 14 Pro Max': {
    viewport: { width: 430, height: 932 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  // Android phones
  'Pixel 5': {
    viewport: { width: 393, height: 851 },
    deviceScaleFactor: 2.75,
    isMobile: true,
    hasTouch: true,
  },

  'Samsung Galaxy S21': {
    viewport: { width: 360, height: 800 },
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  // Tablets
  'iPad Mini': {
    viewport: { width: 768, height: 1024 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },

  'iPad Pro 12.9': {
    viewport: { width: 1024, height: 1366 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },

  // Foldables
  'Samsung Galaxy Fold': {
    viewport: { width: 280, height: 653 }, // Folded
    deviceScaleFactor: 3,
    isMobile: true,
    hasTouch: true,
  },

  'Samsung Galaxy Fold Unfolded': {
    viewport: { width: 717, height: 512 },
    deviceScaleFactor: 2.625,
    isMobile: true,
    hasTouch: true,
  },
};

export type DeviceName = keyof typeof customDevices;
```

### Responsive Tests

```typescript
// e2e/playwright/tests/responsive.spec.ts

import { test, expect } from '@playwright/test';
import { customDevices } from '../utils/device-profiles';

const testDevices = [
  'iPhone SE',
  'iPhone 12',
  'iPhone 14 Pro Max',
  'Pixel 5',
  'iPad Mini',
  'iPad Pro 12.9',
] as const;

test.describe('Responsive Design', () => {
  for (const deviceName of testDevices) {
    test.describe(`on ${deviceName}`, () => {
      test.use({
        viewport: customDevices[deviceName].viewport,
        isMobile: customDevices[deviceName].isMobile,
        hasTouch: customDevices[deviceName].hasTouch,
      });

      test('home screen renders correctly', async ({ page }) => {
        await page.goto('/');
        await page.waitForLoadState('networkidle');

        // Check main elements are visible
        await expect(page.locator('[data-testid="game-list"]')).toBeVisible();

        // Screenshot for visual comparison
        await expect(page).toHaveScreenshot(`home-${deviceName}.png`, {
          fullPage: true,
        });
      });

      test('game screen layout adapts correctly', async ({ page }) => {
        await page.goto('/game/test-room');
        await page.waitForLoadState('networkidle');

        // Check cards are visible
        await expect(page.locator('[data-testid="player-hand"]')).toBeVisible();

        // Check play area is visible
        await expect(page.locator('[data-testid="play-area"]')).toBeVisible();

        // On mobile, check that controls are touch-friendly
        if (customDevices[deviceName].isMobile) {
          const cardSize = await page.locator('[data-testid="card"]').first().boundingBox();
          // Cards should be at least 44x44 for touch targets
          expect(cardSize?.width).toBeGreaterThanOrEqual(44);
          expect(cardSize?.height).toBeGreaterThanOrEqual(60);
        }

        await expect(page).toHaveScreenshot(`game-${deviceName}.png`);
      });

      test('chat panel works on device', async ({ page }) => {
        await page.goto('/game/test-room');

        // Open chat
        await page.click('[data-testid="chat-toggle"]');
        await expect(page.locator('[data-testid="chat-panel"]')).toBeVisible();

        // Type message
        await page.fill('[data-testid="chat-input"]', 'Hello!');
        await page.click('[data-testid="chat-send"]');

        // Verify message appears
        await expect(page.locator('text=Hello!')).toBeVisible();

        await expect(page).toHaveScreenshot(`chat-${deviceName}.png`);
      });

      test('navigation is accessible', async ({ page }) => {
        await page.goto('/');

        // On mobile, hamburger menu should exist
        if (customDevices[deviceName].isMobile) {
          const hamburger = page.locator('[data-testid="menu-toggle"]');
          if (await hamburger.isVisible()) {
            await hamburger.click();
            await expect(page.locator('[data-testid="nav-menu"]')).toBeVisible();
          }
        }

        // Bottom nav should be visible on mobile
        const bottomNav = page.locator('[data-testid="bottom-nav"]');
        if (customDevices[deviceName].isMobile) {
          await expect(bottomNav).toBeVisible();
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
    await expect(page).toHaveScreenshot('game-tablet-portrait.png');

    // Landscape
    await page.setViewportSize({ width: 1024, height: 768 });
    await page.waitForTimeout(500); // Wait for layout adjustment
    await expect(page).toHaveScreenshot('game-tablet-landscape.png');

    // Verify table layout changed
    const playArea = await page.locator('[data-testid="play-area"]').boundingBox();
    expect(playArea?.width).toBeGreaterThan(playArea?.height || 0);
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

    const card = page.locator('[data-testid="card"]').first();
    await card.tap();

    await expect(card).toHaveAttribute('data-selected', 'true');
  });

  test('swipe gestures work for navigation', async ({ page }) => {
    await page.goto('/');

    // Swipe left on game carousel
    const carousel = page.locator('[data-testid="game-carousel"]');
    await carousel.evaluate((el) => {
      el.dispatchEvent(new TouchEvent('touchstart', {
        touches: [{ clientX: 300, clientY: 200 } as Touch],
      }));
      el.dispatchEvent(new TouchEvent('touchend', {
        touches: [{ clientX: 100, clientY: 200 } as Touch],
      }));
    });

    // Verify carousel moved
    // Add specific assertions based on your implementation
  });
});
```

### Accessibility Tests

```typescript
// e2e/playwright/tests/accessibility.spec.ts

import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility', () => {
  test('home page should have no accessibility violations', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('game screen should have no accessibility violations', async ({ page }) => {
    await page.goto('/game/test-room');
    await page.waitForLoadState('networkidle');

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .exclude('[data-testid="card-image"]') // Exclude decorative images
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('color contrast is sufficient', async ({ page }) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
      .withTags(['cat.color'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  test('keyboard navigation works', async ({ page }) => {
    await page.goto('/');

    // Tab through interactive elements
    await page.keyboard.press('Tab');
    const firstFocused = await page.evaluate(() => document.activeElement?.tagName);
    expect(firstFocused).toBeTruthy();

    // Continue tabbing
    for (let i = 0; i < 10; i++) {
      await page.keyboard.press('Tab');
      const focused = await page.evaluate(() => {
        const el = document.activeElement;
        return {
          tag: el?.tagName,
          hasVisibleFocus: window.getComputedStyle(el!).outlineStyle !== 'none',
        };
      });

      // Interactive elements should have visible focus
      if (['BUTTON', 'A', 'INPUT'].includes(focused.tag || '')) {
        // Focus should be visible (either outline or other indicator)
      }
    }
  });

  test('screen reader labels are present', async ({ page }) => {
    await page.goto('/game/test-room');

    // Cards should have aria-labels
    const cards = page.locator('[data-testid="card"]');
    const count = await cards.count();

    for (let i = 0; i < count; i++) {
      const ariaLabel = await cards.nth(i).getAttribute('aria-label');
      expect(ariaLabel).toBeTruthy();
      expect(ariaLabel).toMatch(/\w+ of \w+/); // e.g., "Ace of Hearts"
    }

    // Play button should be labeled
    await expect(page.locator('[data-testid="play-button"]')).toHaveAttribute(
      'aria-label',
      /play card/i
    );
  });
});
```

### Game Flow Tests

```typescript
// e2e/playwright/tests/game-flow.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Complete Game Flow', () => {
  test('user can play a full game of Twenty-Nine', async ({ page }) => {
    // Login
    await page.goto('/');
    await page.click('text=Continue as Guest');
    await page.waitForURL('**/home');

    // Navigate to Twenty-Nine
    await page.click('text=Twenty-Nine');
    await page.waitForURL('**/lobby**');

    // Create room
    await page.click('text=Create Room');
    await page.waitForURL('**/room/**');

    // Add bots
    for (let i = 0; i < 3; i++) {
      await page.click('text=Add Bot');
      await page.click('text=Medium');
    }

    // Verify 4 players
    await expect(page.locator('[data-testid="player-slot"]')).toHaveCount(4);

    // Ready up
    await page.click('text=Ready');
    await expect(page.locator('text=Not Ready')).toHaveCount(0);

    // Start game
    await page.click('text=Start Game');
    await page.waitForURL('**/game/**');

    // Verify game screen loaded
    await expect(page.locator('[data-testid="game-table"]')).toBeVisible();
    await expect(page.locator('[data-testid="player-hand"]')).toBeVisible();

    // Wait for bidding phase
    await expect(page.locator('text=Bidding')).toBeVisible({ timeout: 5000 });

    // Take screenshot of bidding phase
    await expect(page).toHaveScreenshot('game-bidding-phase.png');

    // Place a bid or pass
    const bidButton = page.locator('[data-testid="bid-16"]');
    if (await bidButton.isEnabled()) {
      await bidButton.click();
    } else {
      await page.click('[data-testid="pass-button"]');
    }

    // Wait for game to progress (bots will play)
    await page.waitForTimeout(5000);

    // Game should be in playing phase or completed
    const phase = await page.locator('[data-testid="game-phase"]').textContent();
    expect(['Playing', 'Scoring', 'Finished']).toContain(phase);
  });
});
```

---

## 5. Melos Test Commands

```yaml
# melos.yaml additions

scripts:
  # Unit tests
  test:unit:
    run: melos exec -- flutter test test/unit
    description: Run unit tests
    packageFilters:
      dirExists: test/unit

  # Widget tests
  test:widget:
    run: melos exec -- flutter test test/widget
    description: Run widget tests
    packageFilters:
      dirExists: test/widget

  # Golden tests
  test:golden:
    run: melos exec -- flutter test --update-goldens test/widget/goldens
    description: Update golden files
    packageFilters:
      dirExists: test/widget/goldens

  # Integration tests
  test:integration:
    run: melos exec -- flutter test integration_test
    description: Run integration tests
    packageFilters:
      dirExists: integration_test

  # All tests
  test:all:
    run: melos run test:unit && melos run test:widget && melos run test:integration
    description: Run all tests

  # E2E with Playwright
  test:e2e:
    run: |
      cd apps/flutter_app/e2e/playwright && \
      npm install && \
      npx playwright test
    description: Run Playwright E2E tests

  # E2E specific device
  test:e2e:mobile:
    run: |
      cd apps/flutter_app/e2e/playwright && \
      npx playwright test --project="Mobile Chrome" --project="Mobile Safari"
    description: Run E2E tests on mobile devices

  # Coverage
  test:coverage:
    run: |
      melos exec -- flutter test --coverage && \
      melos exec -- genhtml coverage/lcov.info -o coverage/html
    description: Generate test coverage report
```

---

## 6. CI/CD Pipeline

```yaml
# .github/workflows/test.yml

name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - name: Install Melos
        run: dart pub global activate melos
      - name: Bootstrap
        run: melos bootstrap
      - name: Run unit tests
        run: melos run test:unit
      - name: Upload coverage
        uses: codecov/codecov-action@v3

  widget-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: melos bootstrap
      - name: Run widget tests
        run: melos run test:widget
      - name: Upload golden failures
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: golden-failures
          path: '**/failures/*.png'

  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install Playwright
        run: |
          cd apps/flutter_app/e2e/playwright
          npm ci
          npx playwright install --with-deps
      - name: Build Flutter Web
        run: |
          cd apps/flutter_app
          flutter build web
      - name: Run E2E tests
        run: melos run test:e2e
      - name: Upload test report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: apps/flutter_app/e2e/playwright/playwright-report/
```

---

## Expected Output

- Unit tests for all game rules (write before implementation)
- Widget tests with golden image comparison
- Integration tests for user flows
- Playwright E2E tests across 10+ device profiles
- Accessibility testing (WCAG compliance)
- CI/CD pipeline for automated testing
- Coverage reporting
- Visual regression testing
