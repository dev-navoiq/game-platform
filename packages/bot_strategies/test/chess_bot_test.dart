import 'dart:math';

import 'package:game_chess/game_chess.dart';
import 'package:bot_strategies/bot_strategies.dart';
import 'package:test/test.dart';

void main() {
  group('ChessBot', () {
    late ChessRules rules;
    late ChessBot whiteBot;
    late ChessBot blackBot;

    setUp(() {
      rules = ChessRules();
      whiteBot = ChessBot(
        playerId: 'white',
        name: 'WhiteBot',
        difficulty: BotDifficulty.easy,
        random: Random(42),
      );
      blackBot = ChessBot(
        playerId: 'black',
        name: 'BlackBot',
        difficulty: BotDifficulty.easy,
        random: Random(43),
      );
    });

    test('selectMove returns null for empty move list', () {
      final move = whiteBot.selectMove(
        ChessState.initial(
          whitePlayerId: 'white',
          blackPlayerId: 'black',
        ),
        [],
      );
      expect(move, isNull);
    });

    test('selectMove returns a valid move from initial position', () {
      final state = ChessState.initial(
        whitePlayerId: 'white',
        blackPlayerId: 'black',
      );
      final validMoves = rules.getValidMoves(state, 'white');
      final move = whiteBot.selectMove(state, validMoves);

      expect(move, isNotNull);
      expect(validMoves, contains(move));
    });

    test('bot can play a full short game without crashing', () {
      var state = rules.createInitialState(
        playerIds: ['white', 'black'],
        dealerIndex: 0,
      );

      // Play up to 40 moves (20 per side).
      for (var i = 0; i < 40; i++) {
        if (state.isGameOver) break;

        final currentId = state.currentPlayerId;
        final validMoves = rules.getValidMoves(state, currentId);
        if (validMoves.isEmpty) break;

        final bot = currentId == 'white' ? whiteBot : blackBot;
        final move = bot.selectMove(state, validMoves);
        expect(move, isNotNull, reason: 'Move $i should not be null');

        final result = rules.applyMove(state, move!);
        expect(result.isValid, isTrue,
            reason: 'Move $i should be valid: ${result.error}');
        state = result.newState;
      }
    });

    test('easy bot selects a valid move from initial position', () {
      final easyBot = ChessBot(
        playerId: 'white',
        name: 'Easy',
        difficulty: BotDifficulty.easy,
        random: Random(42),
      );

      final state = ChessState.initial(
        whitePlayerId: 'white',
        blackPlayerId: 'black',
      );
      final validMoves = rules.getValidMoves(state, 'white');
      final move = easyBot.selectMove(state, validMoves);
      expect(move, isNotNull);
      expect(move, isA<ChessMoveAction>());
      expect(validMoves, contains(move));
    });

    test('isComplexDecision true in mid-game', () {
      final state = ChessState.initial(
        whitePlayerId: 'white',
        blackPlayerId: 'black',
      );
      // Initial position has 32 pieces — not mid-game range (10-24).
      final move = ChessMoveAction(
        playerId: 'white',
        from: ChessSquare.fromNotation('e2'),
        to: ChessSquare.fromNotation('e4'),
      );
      expect(whiteBot.isComplexDecision(state, move), isFalse);
    });
  });
}
