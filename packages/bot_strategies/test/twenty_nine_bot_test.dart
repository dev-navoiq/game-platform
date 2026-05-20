import 'dart:math';

import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';
import 'package:bot_strategies/bot_strategies.dart';
import 'package:test/test.dart';

void main() {
  group('TwentyNineBot', () {
    late TwentyNineRules rules;
    late TwentyNineBot bot;
    final players = ['bot1', 'p2', 'p3', 'p4'];

    setUp(() {
      rules = TwentyNineRules();
      bot = TwentyNineBot(
        playerId: 'bot1',
        name: 'TestBot',
        difficulty: BotDifficulty.hard,
        random: Random(42),
      );
    });

    test('selectMove returns null for empty move list', () {
      final move = bot.selectMove(
        _createDummyState(players),
        [],
      );
      expect(move, isNull);
    });

    test('selectMove returns a valid move during bidding', () {
      final state = rules.createInitialState(
        playerIds: players,
        dealerIndex: 0,
      );

      final validMoves = rules.getValidMoves(state, state.currentPlayerId);

      if (state.currentPlayerId == 'bot1' && validMoves.isNotEmpty) {
        final move = bot.selectMove(state, validMoves);
        expect(move, isNotNull);
        expect(validMoves, contains(move));
      }
    });

    test('selectMove always picks from valid moves', () {
      final state = rules.createInitialState(
        playerIds: players,
        dealerIndex: 3,
      );

      var current = state;
      for (var i = 0; i < 20; i++) {
        final pid = current.currentPlayerId;
        final moves = rules.getValidMoves(current, pid);
        if (moves.isEmpty) break;

        if (pid == 'bot1') {
          final move = bot.selectMove(current, moves);
          expect(move, isNotNull);
          expect(moves, contains(move));
          break;
        } else {
          final pass = moves.whereType<PassMove>().firstOrNull;
          if (pass != null) {
            final result = rules.applyMove(current, pass);
            if (!result.isValid) break;
            current = result.newState;
          } else {
            break;
          }
        }
      }
    });

    test('master difficulty always plays optimally', () {
      final masterBot = TwentyNineBot(
        playerId: 'bot1',
        name: 'MasterBot',
        difficulty: BotDifficulty.master,
        random: Random(42),
      );

      var optimalCount = 0;
      for (var i = 0; i < 100; i++) {
        if (masterBot.shouldPlayOptimally()) optimalCount++;
      }
      expect(optimalCount, 100);
    });

    test('beginner difficulty sometimes plays randomly', () {
      final beginnerBot = TwentyNineBot(
        playerId: 'bot1',
        name: 'BeginnerBot',
        difficulty: BotDifficulty.beginner,
        random: Random(42),
      );

      var optimalCount = 0;
      for (var i = 0; i < 100; i++) {
        if (beginnerBot.shouldPlayOptimally()) optimalCount++;
      }
      expect(optimalCount, greaterThan(10));
      expect(optimalCount, lessThan(60));
    });

    test('isComplexDecision returns true for bids', () {
      final state = _createDummyState(players);
      final bidMove = BidMove(playerId: 'bot1', bidValue: 16);
      expect(bot.isComplexDecision(state, bidMove), isTrue);
    });
  });

  group('ThinkTimeCalculator', () {
    test('calculates reasonable durations', () {
      final duration = ThinkTimeCalculator.calculate(
        difficulty: BotDifficulty.medium,
        personality: BotPersonality.balanced,
        isComplexDecision: false,
      );
      expect(duration.inMilliseconds, greaterThan(500));
      expect(duration.inMilliseconds, lessThan(2500));
    });

    test('complex decisions take longer on average', () {
      var simpleTotal = 0;
      var complexTotal = 0;
      for (var i = 0; i < 100; i++) {
        simpleTotal += ThinkTimeCalculator.calculate(
          difficulty: BotDifficulty.medium,
          personality: BotPersonality.balanced,
          isComplexDecision: false,
        ).inMilliseconds;
        complexTotal += ThinkTimeCalculator.calculate(
          difficulty: BotDifficulty.medium,
          personality: BotPersonality.balanced,
          isComplexDecision: true,
        ).inMilliseconds;
      }
      expect(complexTotal, greaterThan(simpleTotal));
    });
  });

  group('BotFactory', () {
    setUp(() => BotFactory.resetNames());

    test('creates TwentyNineBot', () {
      final bot = BotFactory.createBot(
        gameType: 'twenty_nine',
        playerId: 'bot1',
      );
      expect(bot, isA<TwentyNineBot>());
    });

    test('creates OhHellBot', () {
      final bot = BotFactory.createBot(
        gameType: 'oh_hell',
        playerId: 'bot1',
      );
      expect(bot, isA<OhHellBot>());
    });

    test('creates ChessBot', () {
      final bot = BotFactory.createBot(
        gameType: 'chess',
        playerId: 'bot1',
      );
      expect(bot, isA<ChessBot>());
    });

    test('creates LudoBot', () {
      final bot = BotFactory.createBot(
        gameType: 'ludo',
        playerId: 'bot1',
      );
      expect(bot, isA<LudoBot>());
    });

    test('creates SequenceBot', () {
      final bot = BotFactory.createBot(
        gameType: 'sequence',
        playerId: 'bot1',
      );
      expect(bot, isA<SequenceBot>());
    });

    test('creates HeartsBot', () {
      final bot = BotFactory.createBot(
        gameType: 'hearts',
        playerId: 'bot1',
      );
      expect(bot, isA<HeartsBot>());
    });

    test('creates SpadesBot', () {
      final bot = BotFactory.createBot(
        gameType: 'spades',
        playerId: 'bot1',
      );
      expect(bot, isA<SpadesBot>());
    });

    test('throws for unknown game type', () {
      expect(
        () => BotFactory.createBot(
          gameType: 'unknown',
          playerId: 'bot1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('auto-assigns names', () {
      final bot1 = BotFactory.createBot(
        gameType: 'chess',
        playerId: 'b1',
      ) as ChessBot;
      final bot2 = BotFactory.createBot(
        gameType: 'chess',
        playerId: 'b2',
      ) as ChessBot;
      expect(bot1.name, 'Alex');
      expect(bot2.name, 'Jordan');
    });

    test('uses custom name when provided', () {
      final bot = BotFactory.createBot(
        gameType: 'chess',
        playerId: 'b1',
        name: 'CustomName',
      ) as ChessBot;
      expect(bot.name, 'CustomName');
    });
  });
}

TwentyNineState _createDummyState(List<String> players) {
  return TwentyNineState(
    phase: GamePhase.bidding,
    currentPlayerId: players[0],
    playerOrder: players,
    dealerIndex: 3,
    hands: {
      for (final p in players) p: Hand([]),
    },
  );
}
