import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_ludo/game_ludo.dart';

/// A seeded Random that always returns a fixed sequence of values.
class _SeededRandom implements Random {
  final List<int> _values;
  int _index = 0;

  _SeededRandom(this._values);

  @override
  // Stored values are die faces (1–6); convert to 0-based for nextInt(max).
  int nextInt(int max) =>
      (_values[_index++ % _values.length] - 1).clamp(0, max - 1);

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(100) / 100.0;
}

LudoRules rulesWithRolls(List<int> rolls) =>
    LudoRules(const LudoConfig(playerCount: 4), _SeededRandom(rolls));

void main() {
  group('Initial state', () {
    test('4 players, each has 4 tokens at home', () {
      final rules = LudoRules();
      final state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      expect(state.tokens.length, 16);
      expect(state.tokens.every((t) => t.isAtHome), isTrue);
    });

    test('current player is playerIds[dealerIndex]', () {
      final rules = LudoRules();
      final state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 1);
      expect(state.currentPlayerId, 'p2');
    });

    test('phase is playing', () {
      final rules = LudoRules();
      final state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      expect(state.phase, GamePhase.playing);
    });
  });

  group('Roll phase', () {
    test('first valid move is always LudoRollDice', () {
      final rules = LudoRules();
      final state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      final moves = rules.getValidMoves(state, 'p1');
      expect(moves.length, 1);
      expect(moves.first, isA<LudoRollDice>());
    });

    test('cannot roll dice twice', () {
      final rules = rulesWithRolls([3]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      final rollResult = rules.applyMove(state, LudoRollDice(playerId: 'p1'));
      expect(rollResult.isValid, isTrue);
      state = rollResult.newState;
      expect(rules.validateMove(state, LudoRollDice(playerId: 'p1')),
          'already_rolled');
    });

    test('rolling non-6 with all tokens at home → must pass', () {
      final rules = rulesWithRolls([3]); // rolls 3
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      final moves = rules.getValidMoves(state, 'p1');
      expect(moves.length, 1);
      expect(moves.first, isA<LudoPass>());
    });

    test('rolling 6 with all tokens at home → can move token out', () {
      final rules = rulesWithRolls([6]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      final moves = rules.getValidMoves(state, 'p1');
      expect(moves.any((m) => m is LudoMoveToken), isTrue);
    });
  });

  group('Token movement', () {
    test('token enters board on 6', () {
      final rules = rulesWithRolls([6]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      final moveToken = rules.getValidMoves(state, 'p1')
          .whereType<LudoMoveToken>()
          .first;
      state = rules.applyMove(state, moveToken).newState;

      final movedToken =
          state.tokens.firstWhere((t) => t.id == moveToken.tokenId);
      expect(movedToken.position.zone, LudoZone.main);
      expect(movedToken.position.index, LudoPosition.startPosition(LudoColor.red));
    });

    test('rolling 6 grants another turn (canRollAgain)', () {
      final rules = rulesWithRolls([6]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      expect(state.canRollAgain, isTrue);
    });

    test('turn passes to next player after pass', () {
      final rules = rulesWithRolls([4]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);
      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      state = rules.applyMove(state, LudoPass(playerId: 'p1')).newState;
      expect(state.currentPlayerId, 'p2');
    });
  });

  group('Captures', () {
    test('token landing on opponent on non-safe square sends opponent home', () {
      // Set up: p1 has token at main index 10, p2 has token at main index 10
      // p1 rolls 3 from index 7 → lands on 10 → captures p2
      final rules = rulesWithRolls([3]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);

      // Manually place a red token at 7 and a blue token at 10
      final redToken =
          state.tokens.firstWhere((t) => t.color == LudoColor.red && t.id == 'p1_0');
      final blueToken =
          state.tokens.firstWhere((t) => t.color == LudoColor.blue && t.id == 'p2_0');
      final updatedTokens = state.tokens.map((t) {
        if (t.id == redToken.id) return t.moveTo(LudoPosition.main(7));
        if (t.id == blueToken.id) return t.moveTo(LudoPosition.main(10));
        return t;
      }).toList();
      state = state.copyWith(tokens: updatedTokens);

      // p1 rolls 3
      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      expect(state.lastRoll, 3);
      state = rules.applyMove(
          state,
          LudoMoveToken(playerId: 'p1', tokenId: redToken.id, steps: 3)).newState;

      final blue =
          state.tokens.firstWhere((t) => t.id == blueToken.id);
      expect(blue.isAtHome, isTrue, reason: 'Blue token should be sent home');
    });

    test('token on safe square is not captured', () {
      // main index 13 is Blue's safe starting square
      final rules = rulesWithRolls([3]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);

      final redToken = state.tokens.firstWhere((t) => t.id == 'p1_0');
      final blueToken = state.tokens.firstWhere((t) => t.id == 'p2_0');
      final updatedTokens = state.tokens.map((t) {
        if (t.id == redToken.id) return t.moveTo(LudoPosition.main(10));
        if (t.id == blueToken.id) return t.moveTo(LudoPosition.main(13));
        return t;
      }).toList();
      state = state.copyWith(tokens: updatedTokens);

      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      state = rules.applyMove(
          state,
          LudoMoveToken(playerId: 'p1', tokenId: redToken.id, steps: 3)).newState;

      final blue = state.tokens.firstWhere((t) => t.id == blueToken.id);
      expect(blue.isAtHome, isFalse, reason: 'Blue token on safe square survives');
    });
  });

  group('Home stretch', () {
    test('token enters home stretch after passing entry', () {
      // Red home stretch entry = main track 50
      // Place token at 50, roll 1 → homeStretch(0)
      final rules = rulesWithRolls([1]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);

      final token = state.tokens.firstWhere((t) => t.id == 'p1_0');
      state = state.copyWith(
          tokens: state.tokens.map((t) {
        if (t.id == token.id) return t.moveTo(LudoPosition.main(50));
        return t;
      }).toList());

      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      state = rules.applyMove(
          state,
          LudoMoveToken(playerId: 'p1', tokenId: token.id, steps: 1)).newState;

      final moved = state.tokens.firstWhere((t) => t.id == token.id);
      expect(moved.position.zone, LudoZone.homeStretch);
      expect(moved.position.index, 0);
    });

    test('token reaching finish from homeStretch', () {
      final rules = rulesWithRolls([1]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);

      final token = state.tokens.firstWhere((t) => t.id == 'p1_0');
      state = state.copyWith(
          tokens: state.tokens.map((t) {
        if (t.id == token.id) {
          return t.moveTo(LudoPosition.homeStretch(LudoColor.red, 5));
        }
        return t;
      }).toList());

      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      state = rules.applyMove(
          state,
          LudoMoveToken(playerId: 'p1', tokenId: token.id, steps: 1)).newState;

      final moved = state.tokens.firstWhere((t) => t.id == token.id);
      expect(moved.isFinished, isTrue);
    });

    test('overshot from homeStretch returns no valid token move', () {
      final rules = rulesWithRolls([3]);
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);

      final token = state.tokens.firstWhere((t) => t.id == 'p1_0');
      // homeStretch index 5 + 3 steps = 8 > 6 → overshot
      state = state.copyWith(
          tokens: state.tokens.map((t) {
        if (t.id == token.id) {
          return t.moveTo(LudoPosition.homeStretch(LudoColor.red, 5));
        }
        return t;
      }).toList());

      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      final moves = rules.getValidMoves(state, 'p1');
      // If this is the only token and it overshoots, only LudoPass is available
      expect(moves.whereType<LudoMoveToken>().any(
              (m) => m.tokenId == token.id),
          isFalse);
    });
  });

  group('Win condition', () {
    test('player wins when all 4 tokens reach finish', () {
      // Move all 4 red tokens manually to homeStretch index 5, then roll 1 each
      final rules = rulesWithRolls([1, 0, 1, 0, 1, 0, 1]); // 1 for each token finish
      var state = rules.createInitialState(
          playerIds: ['p1', 'p2', 'p3', 'p4'], dealerIndex: 0);

      // Move 3 tokens to finish, 1 to homeStretch(5)
      state = state.copyWith(tokens: state.tokens.map((t) {
        if (t.color != LudoColor.red) return t;
        if (t.id == 'p1_0') {
          return t.moveTo(LudoPosition.homeStretch(LudoColor.red, 5));
        }
        return t.moveTo(LudoPosition.finish(LudoColor.red));
      }).toList());

      expect(state.winnerId, isNull);

      state = rules.applyMove(state, LudoRollDice(playerId: 'p1')).newState;
      expect(state.lastRoll, 1);
      final moveAction = rules.getValidMoves(state, 'p1')
          .whereType<LudoMoveToken>()
          .first;
      state = rules.applyMove(state, moveAction).newState;

      expect(state.isGameOver, isTrue);
      expect(state.winnerId, 'p1');
      expect(state.phase, GamePhase.gameEnd);
      expect(rules.getWinners(state), ['p1']);
    });
  });

  group('Scores', () {
    test('returns 0 for all when game is not over', () {
      final rules = LudoRules();
      final state = rules.createInitialState(
          playerIds: ['p1', 'p2'], dealerIndex: 0);
      expect(rules.calculateScores(state).values.every((v) => v == 0), isTrue);
    });
  });
}
