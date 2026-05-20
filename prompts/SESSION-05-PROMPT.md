# Session 5 — Board Game Implementations

## Load these files first

```
prompts/_context.md
prompts/06-board-game-implementations.md
```

---

## Context: what's already done

**Session 1 ✅** — Monorepo scaffold + Supabase schema
**Session 2 ✅** — Testing infrastructure (test stubs, CI pipeline)
**Session 3 ✅** — `packages/game_core/` fully implemented
**Session 4 ✅** — All 6 card-game packages implemented + stubs

All 3 board-game packages are scaffolded with empty barrel exports:
- `packages/game_chess/lib/game_chess.dart`
- `packages/game_ludo/lib/game_ludo.dart`
- `packages/game_sequence/lib/game_sequence.dart`

Each `pubspec.yaml` already declares `game_core: path: ../game_core` as a dependency.

**There are no pre-written test stubs for board games.** You must write tests alongside the implementation.

---

## Critical: actual `game_core` API you must match

The code in `06-board-game-implementations.md` was written before Session 3 finalised the API.
Several things in that prompt **will not compile** against the real `game_core`. Use the facts below.

### `GameState` abstract class (actual)

```dart
abstract class GameState extends Equatable {
  const GameState();

  GamePhase get phase;
  String? get currentPlayerId;   // nullable in base — see note below
  int get turnNumber;
  int get roundNumber;
  bool get isGameOver;
  RoomSocialMode get socialMode; // REQUIRED — drives chat/voice UI

  Map<String, dynamic> toJson();
  GameState copyWith();

  @override
  List<Object?> get props;
}
```

**No `gameId`, no `playerIds` fields on GameState.** The prompt's
`super(gameId: gameId, playerIds: playerIds, phase: phase)` pattern does **not exist**.
Store playerIds inside your concrete state class (e.g. `final List<String> playerIds`).

**`currentPlayerId` nullability trick**: In Session 4, `TwentyNineState` narrowed
this to non-nullable `String` via a private backing field + `@override String get
currentPlayerId => _currentPlayerId!;`. For chess (always 2 players, always one active),
do the same — it simplifies test code significantly.

### `GameRules` abstract class (actual)

```dart
abstract class GameRules<TState extends GameState, TMove extends GameMove> {
  int get minPlayers;
  int get maxPlayers;
  List<int> get validPlayerCounts;

  TState createInitialState({
    required List<String> playerIds,
    required int dealerIndex,     // use as "first-player index" for board games
    Map<String, dynamic>? serverConfig,
  });

  String? validateMove(TState state, TMove move);       // null = valid
  List<TMove> getValidMoves(TState state, String playerId);
  MoveResult<TState> applyMove(TState state, TMove move);
  bool isGameOver(TState state);
  List<String> getWinners(TState state);
  Map<String, int> calculateScores(TState state);
  String? getNextPlayer(TState state, List<String> playerIds);
  void applyServerConfig(Map<String, dynamic> config);
}
```

### `MoveResult` (actual, already fixed in Session 4)

```dart
factory MoveResult.valid({required TState newState, List<GameEvent> events = const []})
factory MoveResult.invalid({required String error})
TState get newState   // non-nullable getter — throws on invalid result
```

### `GameMove` abstract class (actual)

```dart
abstract class GameMove extends Equatable {
  const GameMove();
  String get playerId;
  MoveType get type;
  DateTime? get timestamp;     // null until server processes
  Map<String, dynamic> toJson();
  List<Object?> get props;
}
```

### `GamePhase` enum (actual — only these values exist)

```dart
enum GamePhase {
  setup, dealing, bidding, trumpSelection, cardPassing,
  playing, scoring, roundEnd, gameEnd,
}
```

Use `GamePhase.playing` for the main play phase and `GamePhase.gameEnd` for terminal state.

### `BoardPiece<T extends PieceType>` (actual, in `game_core`)

```dart
abstract class PieceType { String get name; String get symbol; }

class BoardPiece<T extends PieceType> extends Equatable {
  final T type;
  final String ownerId;
  final int teamIndex;
  final bool hasMoved;
  BoardPiece copyWith({...});
}
```

You **may** use `BoardPiece` or roll your own piece classes — either is fine.
For chess the prompt's hand-rolled `ChessPiece` approach is simpler and recommended.

### `BoardPosition` (actual, in `game_core`)

```dart
class BoardPosition extends Equatable {
  const BoardPosition({required int row, required int col});
  bool get isValid;        // always true — validity is context-dependent
  BoardPosition offset(int dr, int dc);
  List<BoardPosition> get orthogonalNeighbours;
}
```

### `GameConfig` — does NOT exist

There is no `GameConfig` base class in `game_core`. Just make each config a plain Dart class.

---

## Package structure for each game

```
packages/game_{name}/
├── lib/
│   ├── game_{name}.dart            ← barrel export (update from stub)
│   └── src/
│       ├── {name}_config.dart      ← constants / enums (no GameConfig base)
│       ├── {name}_state.dart       ← GameState subclass
│       ├── {name}_move.dart        ← sealed GameMove hierarchy
│       ├── {name}_rules.dart       ← GameRules subclass
│       ├── {name}_piece.dart       ← piece types / board representation
│       ├── {name}_board.dart       ← board class (chess/sequence only)
│       └── {name}_factory.dart     ← register with GameRegistry
└── test/
    └── {name}_rules_test.dart      ← write these yourself
```

---

## Priority order

1. **Implement `game_chess`** — full rules, move validation, checkmate/stalemate/draw detection
2. **Implement `game_ludo`** — dice rolling, safe squares, home column, win detection
3. **Implement `game_sequence`** — card-play → chip placement, sequence detection, win condition
4. **Write tests** for each game (at minimum: initial state, legal moves, win detection)

---

## Game rules summary

### Chess

- 2 players (white/black), `playerIds[0]` = white, `playerIds[1]` = black
- Full standard rules: all 6 piece movements, en passant, castling, promotion
- End conditions: checkmate, stalemate (draw), 50-move rule, threefold repetition,
  insufficient material, resignation
- **Notation**: `ChessSquare` as in the prompt (file 0-7, rank 0-7); `toFEN()` / `fromFEN()`
  are useful for position history (threefold repetition)
- `dealerIndex` → ignored (white always goes first)
- Score: winner gets 1, draw gets 0 for both

### Ludo

- 2–4 players, each has 4 tokens
- Tokens start in home base, must enter board on a 6, travel 52 squares, then ascend
  home column (6 safe home-column squares per player) to reach home
- Safe squares: star squares (8 on standard board) + each player's starting square
- Capture: landing on opponent's token (not on a safe square) sends it back to base
- Win: first player to get all 4 tokens home
- Dice: single d6; must roll 6 to enter board; roll 6 = bonus turn; blocked = forfeit
- `dealerIndex` → first player index (that player rolls first)

### Sequence

- 2–4 players (or 2 teams of 2), uses 2 standard 52-card decks + board
- 10×10 board with cards on each square (corner squares are free/wild)
- On your turn: play a card from hand → place a chip on matching board square
  - Two-eyed Jacks (wild): place chip anywhere
  - One-eyed Jacks (anti-wild): remove any opponent chip
- Win: first to complete N sequences (lines of 5 chips, any direction)
  - 2 players: 2 sequences to win
  - 3 players: 1 sequence to win
  - 4 players (2v2 teams): 2 sequences to win
- Draw 1 card after each play; hand size = 7 (2-3 players) or 6 (4 players)
- `dealerIndex` → deals cards and goes last

---

## Verification

```bash
# After implementing, from the monorepo root:
cd packages/game_chess && fvm flutter test
cd ../game_ludo && fvm flutter test
cd ../game_sequence && fvm flutter test

# Also ensure game_core remains green:
cd ../game_core && fvm flutter test
```

---

## Constraints

- Pure Dart in `lib/` — no Flutter SDK imports
- All public classes must be `Equatable` or override `==`/`hashCode`
- No network calls, no async — synchronous game-logic layer only
- Use `fvm flutter test` (not `flutter test`)
- Do NOT implement:
  - Chess variants (Chess960, Crazyhouse, etc.) — standard only
  - Time controls — clock logic is UI-layer only
  - Bot strategies (Session 6)
  - UI screens

---

## Key API decisions you must make (decide before coding)

| Question | Recommendation |
|----------|----------------|
| Where do `playerIds` live? | In each concrete state class (NOT in `GameState`) |
| Chess `currentPlayerId` nullable? | No — narrow to `String` (see Session 4 pattern) |
| Ludo dice: store in state? | Yes — `final int? lastRoll` on LudoState |
| Sequence board: how to represent? | `Map<BoardPosition, SequenceCell>` where cell tracks chip color |
| `dealerIndex` for chess? | Ignored; white = `playerIds[0]`, always moves first |
| `calculateScores` for chess? | `{whiteId: 1, blackId: 0}` on win, `{whiteId: 0, blackId: 0}` on draw |
