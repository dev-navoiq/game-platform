# Session 6 — Bot Strategies

## Load these files first

```
prompts/_context.md
prompts/07-bot-strategies.md
```

---

## Context: what's already done

**Session 1 ✅** — Monorepo scaffold + Supabase schema
**Session 2 ✅** — Testing infrastructure (test stubs, CI pipeline)
**Session 3 ✅** — `packages/game_core/` fully implemented
**Session 4 ✅** — All 6 card-game packages implemented + stubs
**Session 5 ✅** — All 3 board-game packages implemented + tested (56 tests, all green)

`packages/bot_strategies/` is scaffolded with an empty barrel export:
- `packages/bot_strategies/lib/bot_strategies.dart`

The `pubspec.yaml` currently only declares `game_core` as a dependency — see the fix below.

---

## Critical fix #1: add game package dependencies to pubspec.yaml

The current `packages/bot_strategies/pubspec.yaml` is missing all the game packages. Replace the `dependencies` block with:

```yaml
dependencies:
  game_core:
    path: ../game_core
  game_twenty_nine:
    path: ../game_twenty_nine
  game_oh_hell:
    path: ../game_oh_hell
  game_hearts:
    path: ../game_hearts
  game_spades:
    path: ../game_spades
  game_chess:
    path: ../game_chess
  game_ludo:
    path: ../game_ludo
  game_sequence:
    path: ../game_sequence
  equatable: ^2.0.5
  collection: ^1.18.0
  meta: ^1.11.0
```

(game_bridge and game_rummy are stubs with no logic to import — skip them.)

---

## Critical fix #2: card game state API

The code in `07-bot-strategies.md` was written before Sessions 3–4 finalised the API. The field names below **will not compile** against the real implementations.

### `Hand` type — not `List<PlayingCard>`

All card game states store hands as `Map<String, Hand>` where `Hand` is a class (not a raw list). Key API:

```dart
Hand hand = state.hands['alice']!;

hand.cards           // List<PlayingCard> — unmodifiable view
hand.size            // int
hand.hasSuit(suit)   // bool
hand.cardsOfSuit(suit) // List<PlayingCard>
hand.contains(card)  // bool
```

When you need to iterate: `hand.cards.where(...)`.

### TwentyNineState — actual fields

```dart
// WRONG in prompt:  state.playerHands['alice']
// CORRECT:          state.hands['alice']!.cards

state.hands              // Map<String, Hand>
state.currentTrick       // List<TrickCard>
state.currentBid         // int  (0 if no bid yet)
state.bidderId           // String?
state.trumpSuit          // Suit?
state.trumpRevealed      // bool
state.trumpSelector      // String? (partner of bidder who calls trump)
state.playerOrder        // List<String> (turn order)
state.dealerIndex        // int
state.teamPoints         // Map<int, int> (team index → points this round)
state.tricksWon          // Map<int, int> (team index → tricks won)
state.passCount          // int
state.sessionScores      // Map<int, int> (team index → game score)
```

TwentyNine move types (sealed):
```dart
TwentyNineBid(playerId: id, bid: 17)       // bid value 16–29 (or 28+1 for 29 bid)
TwentyNinePass(playerId: id)
TwentyNineSelectTrump(playerId: id, suit: Suit.hearts)
TwentyNinePlayCard(playerId: id, card: card)
```

Partnership: players at indices 0 & 2 are team 0; players at indices 1 & 3 are team 1.
```dart
final bidderIndex = state.playerOrder.indexOf(state.bidderId!);
final teamIndex = bidderIndex % 2; // 0 or 1
```

### OhHellState — actual fields

```dart
// WRONG: state.playerHands['alice']
// CORRECT: state.hands['alice']!.cards

state.hands              // Map<String, Hand>
state.currentTrick       // List<TrickCard>
state.bids               // Map<String, int>  (empty until bidding done)
state.tricksWon          // Map<String, int>
state.scores             // Map<String, int>
state.cardsThisRound     // int
state.playerOrder        // List<String>
state.dealerIndex        // int
state.trumpSuit          // Suit  (hearts is always trump in this impl)
```

OhHell move types (sealed):
```dart
OhHellBid(playerId: id, bid: 2)
OhHellPlayCard(playerId: id, card: card)
```

### HeartsState — actual fields

```dart
// WRONG: state.playerHands['alice']
// CORRECT: state.hands['alice']!.cards

state.hands              // Map<String, Hand>
state.currentTrick       // List<TrickCard>
state.scores             // Map<String, int>
state.handPoints         // Map<String, int> (points this hand)
state.heartsBroken       // bool
state.passSelections     // Map<String, List<PlayingCard>> (cards chosen to pass)
state.passDirection      // PassDirection enum (left/right/across/keep)
state.playerOrder        // List<String>
```

Hearts move types (sealed):
```dart
HeartsSelectPass(playerId: id, cards: [c1, c2, c3])
HeartsPlayCard(playerId: id, card: card)
```

### SpadesState — actual fields

```dart
// WRONG: state.playerHands['alice']
// CORRECT: state.hands['alice']!.cards

state.hands              // Map<String, Hand>
state.currentTrick       // List<TrickCard>
state.bids               // Map<String, int>
state.isNilBid           // Map<String, bool>
state.playerTricksWon    // Map<String, int>
state.teamTricksWon      // Map<int, int>
state.teamBags           // Map<int, int>
state.teamScores         // Map<int, int>
state.spadesBroken       // bool
state.playerOrder        // List<String>
state.dealerIndex        // int
```

Spades move types (sealed):
```dart
SpadesBid(playerId: id, bid: 3, isNil: false)
SpadesPlayCard(playerId: id, card: card)
```

### TrickCard (game_core)

```dart
TrickCard card = state.currentTrick.first;
card.playerId   // String
card.card       // PlayingCard
card.suit       // Suit (convenience getter)
card.seatIndex  // int
```

---

## Critical fix #3: board game state APIs

### ChessState — actual fields

```dart
state.board              // ChessBoard
state.activeColor        // ChessColor (white/black)
state.castlingRights     // CastlingRights
state.enPassantSquare    // ChessSquare?
state.halfmoveClock      // int
state.positionHistory    // Map<String, int> (FEN → count, for threefold rep)
state.result             // ChessResult? (null until game over)
state.playerIds          // List<String>  [whiteId, blackId]
state.moveHistory        // List<ChessMove>
```

ChessBoard:
```dart
board.pieces             // Iterable<MapEntry<ChessSquare, ChessPiece>>
board.pieceAt(square)    // ChessPiece?
board.isEmpty(square)    // bool
board.findKing(color)    // ChessSquare?
board.toFEN()            // String
```

ChessPiece:
```dart
piece.type               // ChessPieceType (king/queen/rook/bishop/knight/pawn)
piece.color              // ChessColor (white/black)
piece.hasMoved           // bool
piece.materialValue      // int (Q=9,R=5,B=3,N=3,P=1,K=0)
piece.symbol             // String  e.g. '♛'
piece.notation           // String  e.g. 'Q'
```

ChessSquare:
```dart
ChessSquare(file, rank)               // 0-indexed (a=0, h=7; rank 1=0, rank 8=7)
ChessSquare.fromNotation('e2')
square.notation                        // 'e2'
square.offset(df, dr)                  // ChessSquare
square.isValid                         // bool
```

Chess moves:
```dart
ChessMoveAction(playerId: id, from: sq, to: sq, promotion: ChessPieceType.queen)
ChessResign(playerId: id)
```

### LudoState — actual fields

```dart
state.tokens             // List<LudoToken>  (all players, flat)
state.tokensFor(playerId) // List<LudoToken>
state.playerColors       // Map<String, LudoColor>
state.currentPlayerIndex // int
state.lastRoll           // int?  (null if player hasn't rolled yet)
state.canRollAgain       // bool
state.consecutiveSixes   // int
state.finishedPlayers    // List<String>
state.winnerId           // String?
```

LudoToken:
```dart
token.id                 // String  e.g. 'p1_0'
token.color              // LudoColor (red/blue/green/yellow)
token.position           // LudoPosition
token.isAtHome           // bool
token.isFinished         // bool
```

LudoPosition:
```dart
position.zone            // LudoZone (home/main/homeStretch/finish)
position.index           // int
position.color           // LudoColor
position.isSafe          // bool (main-track safe squares)
LudoPosition.startPosition(color)      // int  (0/13/26/39)
LudoPosition.homeStretchEntry(color)   // int  (50/11/24/37)
LudoPosition.safeSquares               // Set<int>
```

Ludo moves:
```dart
LudoRollDice(playerId: id)
LudoMoveToken(playerId: id, tokenId: 'p1_0', steps: 3)
LudoPass(playerId: id)
```

### SequenceState — actual fields

```dart
// Sequence uses playerHands (List<PlayingCard>), NOT Hand objects
state.playerHands        // Map<String, List<PlayingCard>>
state.board              // SequenceBoard
state.playerColors       // Map<String, ChipColor>  (e.g. 'alice' → ChipColor.red)
state.sequenceCount      // Map<ChipColor, int>
state.drawPileSize       // int
state.drawPile           // List<PlayingCard>
state.playerIds          // List<String>
state.winnerId           // String?
```

SequenceBoard:
```dart
board.cellAt(row, col)            // SequenceCell
board.positionsForCard(card)      // List<(int, int)>
board.isOccupied(row, col)        // bool
```

SequenceCell:
```dart
cell.card                // PlayingCard?  (null for corners)
cell.chip                // ChipColor?
cell.isCorner            // bool
cell.isPartOfSequence    // bool  (locked chip — can't be removed)
```

Sequence moves:
```dart
SequenceMove(playerId: id, card: card, row: r, col: c)
SequenceMove(playerId: id, card: oneEyedJack, row: r, col: c, isRemoval: true)
```

Jack identification helpers (implement in SequenceBot):
```dart
bool isTwoEyedJack(PlayingCard c) =>
    c.rank == Rank.jack && (c.suit == Suit.diamonds || c.suit == Suit.clubs);
bool isOneEyedJack(PlayingCard c) =>
    c.rank == Rank.jack && (c.suit == Suit.hearts || c.suit == Suit.spades);
```

---

## Priority order

1. **Fix `pubspec.yaml`** — add all game package dependencies, run `fvm flutter pub get`
2. **Core framework** — `BotPlayer`, `BotDifficulty`, `ThinkTimeCalculator`, `BotPersonality`, `BotFactory`
3. **TwentyNineBot** — bidding, trump selection, card play (full logic)
4. **OhHellBot** — bidding (hand-strength based), play (try-to-win/lose by count)
5. **ChessBot** — minimax with alpha-beta pruning, material + positional eval
6. **LudoBot** — prioritise captures > entering homeStretch > progress > safe squares
7. **SequenceBot** — prioritise sequence-completing moves > safe placement > two-eyed jack
8. **Stub bots** — HeartsBot, SpadesBot, RummyBot (random legal move from `getValidMoves`)
9. **Tests** — at minimum: `twenty_nine_bot_test.dart`, `chess_bot_test.dart`, `ludo_bot_test.dart`

---

## `getValidMoves` usage pattern

All bots should delegate legal-move generation to the game rules, never recompute it:

```dart
// Generic pattern for any bot
final moves = _rules.getValidMoves(state, playerId);
if (moves.isEmpty) return _fallbackMove(state, playerId);
// Evaluate and pick best move from moves list
```

The rules objects must be instantiated in each bot. Import them from their respective packages:
```dart
import 'package:game_chess/game_chess.dart';
import 'package:game_ludo/game_ludo.dart';
// etc.
```

---

## Offline-first constraint

Bots **must run entirely synchronously** on the client — no `async`, no `Future`, no network. The `selectMove()` method returns `TMove` directly. `ThinkTimeCalculator.getThinkTime()` just returns a `Duration` value; the delay is applied by the UI layer, not the bot itself.

---

## Verification

```bash
cd packages/bot_strategies && fvm flutter test --timeout 60s

# Confirm all game packages still pass:
cd ../game_chess && fvm flutter test --timeout 60s
cd ../game_ludo && fvm flutter test --timeout 60s
cd ../game_sequence && fvm flutter test --timeout 60s
```

---

## Constraints

- Pure Dart in `lib/` — no Flutter SDK imports
- All bots synchronous — no `async`, no `Future`, no network calls
- `BotPlayer<TState, TMove>` is generic — do not hardcode state types in the abstract class
- Use `fvm flutter test` (not `flutter test`)
- Do NOT implement:
  - UI screens or timers (delay is the UI's job)
  - Supabase or server-side logic
  - Full Hearts/Spades/Rummy bots — random-move stubs are sufficient for Session 6
  - Bridge bot (bridge is a stub game with no rules yet)
