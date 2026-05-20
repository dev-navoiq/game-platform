# Session 4 — Card Game Implementations

## Load these files first

```
prompts/_context.md
prompts/05-card-game-implementations.md
```

---

## Context: what's already done

**Session 1 ✅** — Monorepo scaffold + Supabase schema
**Session 2 ✅** — Testing infrastructure (test stubs, CI pipeline)
**Session 3 ✅** — `packages/game_core/` fully implemented

All 6 card-game packages are already scaffolded with empty barrel exports:
- `packages/game_twenty_nine/lib/game_twenty_nine.dart`
- `packages/game_oh_hell/lib/game_oh_hell.dart`
- `packages/game_hearts/lib/game_hearts.dart`
- `packages/game_spades/lib/game_spades.dart`
- `packages/game_bridge/lib/game_bridge.dart`
- `packages/game_rummy/lib/game_rummy.dart`

Each `pubspec.yaml` already declares `game_core: path: ../game_core` as a dependency.

---

## Breaking change you must fix first

The Session 2 test stubs revealed that `MoveResult` (in `packages/game_core/`) has the wrong API.
**Before writing any card-game code**, update `game_core` to match what the tests expect:

### Current (wrong) in `game_core/lib/src/rules/game_rules.dart`

```dart
factory MoveResult.valid(TState state, {List<GameEvent> events = const []})
factory MoveResult.invalid(String errorCode)

final TState? newState;   // nullable — causes type error when tests do: state = result.newState
```

### Required (correct) API — derived from `packages/game_twenty_nine/test/twenty_nine_moves_test.dart`

```dart
// Named parameters on both factories
factory MoveResult.valid({required TState newState, List<GameEvent> events = const []})
factory MoveResult.invalid({required String error})

// newState must be non-nullable (direct assignment without ! in tests)
TState get newState => _newState!;   // throws on invalid — acceptable; tests only call on valid
```

Test evidence:
```dart
// twenty_nine_moves_test.dart lines 75-84
final result = MoveResult.valid(newState: state);
expect(result.isValid, isTrue);
expect(result.error, isNull);

final result = MoveResult.invalid(error: 'NOT_YOUR_TURN');
expect(result.isValid, isFalse);
expect(result.error, 'NOT_YOUR_TURN');

// twenty_nine_rules_test.dart — direct (non-null) assignment
state = rules.applyMove(state, BidMove(...)).newState;  // no ! operator
```

---

## Your task for this session

### Priority order

1. **Fix `MoveResult` in game_core** (5 min) — as described above
2. **Implement `game_twenty_nine`** (full implementation with passing tests)
3. **Implement `game_oh_hell`** (full implementation with passing tests)
4. **Implement `game_hearts`** (rules + scoring; tests may be stubs only)
5. **Implement `game_spades`** (rules + scoring; tests may be stubs only)
6. **Stub `game_bridge` and `game_rummy`** with correct package structure (no rules yet — too complex for one session)

---

## Exact API shape (derived from Session 2 test stubs)

### TwentyNineState

**Constructor** (all named params):
```dart
TwentyNineState({
  required GamePhase phase,
  String? currentPlayerId,
  required Map<String, Hand> hands,
  List<TrickCard> currentTrick = const [],
  Suit? trumpSuit,
  bool trumpRevealed = false,
  int currentBid = 0,            // int, NOT int? — use 0 for "no bid"
  String? bidderId,
  String? trumpSelector,
  required int dealerIndex,
  required List<String> playerOrder,
  Map<int, int> sessionScores = const {0: 0, 1: 0},
  bool allPlayersPassed = false, // explicit field, also computable from passCount
  int turnNumber = 0,
  int roundNumber = 1,
})
```

**Getters/methods** (from state_test.dart):
```dart
int teamForPlayer(String playerId)   // 0 or 1 — NOT getTeamForPlayer
String? get nextPlayerId             // next in playerOrder after currentPlayerId
bool get allPlayersPassed            // either field or computed: passCount >= 4
```

**Note**: The `minimumBid` getter must start at 15 when no bid exists (currentBid == 0):
```dart
int get minimumBid => currentBid == 0 ? 15 : currentBid + 1;
```

### TrickCard

Add a `.suit` getter (used in integration test):
```dart
class TrickCard {
  final String playerId;
  final PlayingCard card;
  final int seatIndex;

  Suit get suit => card.suit;  // ← integration test uses currentTrick.first.suit
}
```

### TwentyNineConfig

Two static methods required by scoring test:
```dart
static int getCardPoints(PlayingCard card)  // J=3, 9=2, A=1, 10=1, else 0
static int cardStrength(PlayingCard card)   // J=8, 9=7, A=6, 10=5, K=4, Q=3, 8=2, 7=1
```

### TwentyNineScorer

Separate class required by scoring test:
```dart
class TwentyNineScorer {
  RoundScoringResult scoreRound({
    required int bid,
    required int biddingTeam,
    required Map<int, int> teamPoints,
    required Map<int, int> gameScores,
  });
}

class RoundScoringResult {
  final bool biddingTeamScored;
  final Map<int, int> updatedGameScores;
}
```

Scoring rules:
- Bid team meets/exceeds bid → `biddingTeamScored = true`, bid team +1 game-point
- Bid team fails normal bid → `biddingTeamScored = false`, defending team +1 game-point
- Bid of 29 and bid met → `biddingTeamScored = true`, bid team **+2 game-points** (greater than 1, per test)

### TwentyNineRules

From rules test — partnerships:
- `playerOrder[0]` and `playerOrder[2]` = team 0
- `playerOrder[1]` and `playerOrder[3]` = team 1
- After bid by p2, 3 passes → `phase = trumpSelection`, `trumpSelector = 'p4'` (p2's partner)
  - p2 is at index 1, partner is at index 3 → `playerOrder[3]` = `'p4'` ✓

### Oh Hell Game

Key rules from `05-card-game-implementations.md`:
- 4–8 players, free-for-all (no teams)
- Round N: deal N cards (descending from max then ascending)
- Trump: **hearts always trump** (fixed, no selection phase)
- Bidding: each player predicts exact tricks they'll win
- Forbidden bid (dealer constraint): dealer's bid cannot make `sum(all bids) == cards dealt`
- Scoring: if exact → `10 + (bid × 1)` points, else `0`
- Game ends after full up/down sequence of rounds

### Hearts Game

Key rules:
- 4 players, free-for-all
- Goal: avoid hearts (1 pt each) and Queen of Spades (13 pts)
- Card passing: left, right, across, keep (rotating each round)
- Shooting the moon: if one player takes all 26 points, others get 26
- Game ends when someone reaches 100 points

### Spades Game

Key rules:
- 4 players, 2v2 teams
- Spades always trump
- Bidding: individual bids, team bid = sum of partners
- Nil bid: 0 tricks (if exact: +100; if failed: -100)
- Bags (overtricks): bag penalty at 10 bags → -100
- Scoring: `(bid × 10) + bags` if made; `-bid × 10` if set

---

## Package structure for each game

Follow the template from `05-card-game-implementations.md`:

```
packages/game_{name}/
├── lib/
│   ├── game_{name}.dart           ← barrel export (update from stub)
│   └── src/
│       ├── {name}_config.dart     ← GameConfig subclass + constants
│       ├── {name}_state.dart      ← GameState subclass
│       ├── {name}_move.dart       ← sealed GameMove hierarchy
│       ├── {name}_rules.dart      ← GameRules subclass
│       ├── {name}_scoring.dart    ← Scorer class + result types
│       └── {name}_factory.dart    ← registers with GameRegistry
└── test/
    └── (existing stubs — do not modify)
```

---

## Verification

```bash
# After implementing, from the monorepo root:
cd packages/game_core && fvm flutter test
cd ../game_twenty_nine && fvm flutter test
```

All tests in `packages/game_core/test/` must remain green.
All tests in `packages/game_twenty_nine/test/` must pass green.

---

## Constraints

- Pure Dart in `lib/` — no Flutter SDK imports
- All public classes must be `Equatable` or override `==`/`hashCode`
- No network calls, no async — synchronous game-logic layer only
- Do not modify any existing test files
- Use `fvm flutter test` instead of `flutter test`

---

## Do NOT implement in this session

- Board games (Sessions 5–6)
- UI screens, widgets, animations
- Supabase integration
- Bot strategies (Session 6)
