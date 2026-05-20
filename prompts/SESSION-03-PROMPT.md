# Session 3 — Game Core Framework

## Load these files first

```
prompts/_context.md
prompts/04-game-core-package.md
```

---

## Context: what's already done

**Session 1 ✅** — Monorepo scaffold + Supabase schema
- 13 packages stubbed under `packages/` and `apps/flutter_app/`
- Full DB migration at `supabase/migrations/20260226000000_initial_schema.sql`
- `melos.yaml` with bootstrap/analyze/format/clean/get scripts

**Session 2 ✅** — Testing infrastructure (pure stubs, no implementations yet)
- `packages/game_core/test/` — unit test stubs for `PlayingCard`, `Deck`, `Hand`,
  `BoardPosition`, `GameRegistry`
- `packages/game_twenty_nine/test/` — rules / state / moves / scoring stubs
- `packages/bot_strategies/test/` — bot strategy stubs
- `apps/flutter_app/test/` — unit, widget, golden, integration stubs
- `apps/flutter_app/e2e/playwright/` — full Playwright E2E setup (10 device profiles)
- `.github/workflows/test.yml` — CI pipeline

**The test files define the exact API the implementation must satisfy.**
Use them as a spec — your code must make the tests in `packages/game_core/test/`
pass without modifying the test files.

---

## Your task for this session

Implement `packages/game_core/` per **prompt 04** (`04-game-core-package.md`).

### Product-strategy addition (from `_context.md`, Part 3)
Game state must include a `socialMode` field typed as the `RoomSocialMode` enum
(`full | chat_only | silent | focus`) so the UI layer can conditionally render
chat, voice, and floating bubbles without querying the DB on every frame.

### Concrete deliverables

1. **Card primitives** — `PlayingCard`, `Deck` (`standard52`, `standard32`,
   `shuffle`, `draw`, `drawMultiple`), `Hand` (`hasSuit`, `cardsOfSuit`,
   `remove`, `contains`, `size`, `cards`)

2. **Board primitives** — `BoardPosition` (`isValid`, `offset`,
   `orthogonalNeighbours`), `BoardPiece`, `BoardState`, `BoardRules`

3. **Abstract game interfaces** — `GameState` (includes `socialMode`),
   `GameMove`, `GameRules` (`createInitialState`, `validateMove`, `applyMove`,
   `isGameOver`, `getWinners`), `MoveResult` (`valid`/`invalid`)

4. **Enums** — `Suit` (hearts/spades/diamonds/clubs), `Rank` (seven → ace),
   `GamePhase`, `GameCategory` (cardGame/boardGame),
   `RoomSocialMode` (full/chat_only/silent/focus)

5. **Game registry** — `GameDescriptor` (id, name, minPlayers, maxPlayers,
   category), `GameRegistry` (`register`, `lookup`, `registeredGameIds`,
   `gamesByCategory`)

6. **Public barrel export** — `lib/game_core.dart` exports everything above

### Constraints
- Pure Dart — no Flutter SDK imports in `lib/` (the package's `pubspec.yaml`
  already lists only `equatable`, `collection`, `meta` as dependencies)
- All public classes must be `Equatable` or override `==`/`hashCode`
- `GameState` is abstract/sealed — each game package provides a concrete subclass
- `MoveResult` carries `newState` on success and `error` (String error code) on failure
- No network calls, no async — this is a pure synchronous game-logic layer

### Key API shape (derived from Session 2 test stubs)

```dart
// From packages/game_core/test/cards/deck_test.dart
Deck.standard52()   // 52 cards
Deck.standard32()   // 32 cards (7 and up only)
deck.shuffle()
deck.draw()         // → PlayingCard?
deck.drawMultiple(n) // → List<PlayingCard>
deck.remaining      // int

// From packages/game_core/test/cards/hand_test.dart
Hand(List<PlayingCard> cards)
hand.hasSuit(Suit)         // bool
hand.cardsOfSuit(Suit)     // List<PlayingCard>
hand.remove(PlayingCard)   // bool
hand.contains(PlayingCard) // bool
hand.size                  // int
hand.cards                 // List<PlayingCard>

// From packages/game_core/test/board/board_position_test.dart
BoardPosition(row: int, col: int)
pos.isValid(rows: int, cols: int)  // bool
pos.offset(dRow: int, dCol: int)   // BoardPosition
pos.orthogonalNeighbours(rows: int, cols: int) // List<BoardPosition>

// From packages/game_core/test/registry/game_registry_test.dart
GameRegistry()
registry.register(GameDescriptor)
registry.lookup(String id)          // GameDescriptor?
registry.registeredGameIds          // Iterable<String>
registry.gamesByCategory(GameCategory) // List<GameDescriptor>
// Throws ArgumentError on duplicate id
```

---

## Verification

After implementing, run:

```bash
cd packages/game_core
flutter test
```

All tests in `packages/game_core/test/` must pass green.
The `packages/game_twenty_nine/test/` stubs will still fail (expected —
`game_twenty_nine` is Session 4).

---

## Output expected

- `packages/game_core/lib/` fully implemented and exported
- `flutter test` passes for `game_core` package
- No changes needed to any test file
