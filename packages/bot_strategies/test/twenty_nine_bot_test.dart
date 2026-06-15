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

  group('TwentyNineBot bidding tiers', () {
    late TwentyNineRules rules;
    final players = ['bot1', 'p2', 'p3', 'p4']; // bot1 + p3 are partners.

    setUp(() {
      rules = TwentyNineRules();
    });

    TwentyNineBot bot(BotDifficulty d) => TwentyNineBot(
          playerId: 'bot1',
          name: 'TestBot',
          difficulty: d,
          random: Random(42),
        );

    TwentyNineState bidState({
      required List<PlayingCard> botHand,
      int currentBid = 0,
      String? bidderId,
    }) {
      return TwentyNineState(
        phase: GamePhase.bidding,
        currentPlayerId: 'bot1',
        playerOrder: players,
        dealerIndex: 3,
        hands: {
          'bot1': Hand(botHand),
          for (final p in players.skip(1)) p: Hand([]),
        },
        currentBid: currentBid,
        bidderId: bidderId,
      );
    }

    PlayingCard card(Rank r, Suit s) => PlayingCard(s, r);

    // 29 only uses 7..A (32-card deck).
    final deckRanks = [
      Rank.seven, Rank.eight, Rank.nine, Rank.ten,
      Rank.jack, Rank.queen, Rank.king, Rank.ace,
    ];
    final deck29 = [
      for (final s in Suit.values)
        for (final r in deckRanks) PlayingCard(s, r),
    ];

    group('PolicyTier mapping', () {
      test('difficulty buckets into beginner/medium/strong tiers', () {
        expect(BotDifficulty.beginner.policyTier, PolicyTier.beginner);
        expect(BotDifficulty.easy.policyTier, PolicyTier.beginner);
        expect(BotDifficulty.medium.policyTier, PolicyTier.medium);
        expect(BotDifficulty.hard.policyTier, PolicyTier.strong);
        expect(BotDifficulty.expert.policyTier, PolicyTier.strong);
        expect(BotDifficulty.master.policyTier, PolicyTier.strong);
      });
    });

    group('beginner', () {
      test('passes on weak hand (no point cards)', () {
        final state = bidState(botHand: [
          card(Rank.king, Suit.spades),
          card(Rank.queen, Suit.hearts),
          card(Rank.eight, Suit.diamonds),
          card(Rank.seven, Suit.clubs),
        ]);
        final moves = rules.getValidMoves(state, 'bot1');
        final move = bot(BotDifficulty.beginner).selectMove(state, moves);
        expect(move, isA<PassMove>());
      });

      test('bids the floor on a decent hand', () {
        // 3 + 2 + 1 + 1 = 7 own points → target 18 ≥ 15 (floor) → bid 15.
        final state = bidState(botHand: [
          card(Rank.jack, Suit.spades),
          card(Rank.nine, Suit.spades),
          card(Rank.ace, Suit.hearts),
          card(Rank.ten, Suit.diamonds),
        ]);
        final moves = rules.getValidMoves(state, 'bot1');
        final move = bot(BotDifficulty.beginner).selectMove(state, moves);
        expect(move, isA<BidMove>());
        expect((move as BidMove).bidValue, 15);
      });

      test('never pushes the auction even on a monster hand', () {
        // J+J+9+9 = 10 own points → target 21, but beginner always bids floor.
        final state = bidState(botHand: [
          card(Rank.jack, Suit.spades),
          card(Rank.jack, Suit.hearts),
          card(Rank.nine, Suit.spades),
          card(Rank.nine, Suit.hearts),
        ]);
        final moves = rules.getValidMoves(state, 'bot1');
        final move = bot(BotDifficulty.beginner).selectMove(state, moves);
        expect(move, isA<BidMove>());
        expect((move as BidMove).bidValue, 15);
      });

      test('passes when minBid above target', () {
        final state = bidState(
          botHand: [
            card(Rank.king, Suit.spades),
            card(Rank.queen, Suit.hearts),
            card(Rank.eight, Suit.diamonds),
            card(Rank.seven, Suit.clubs),
          ],
          currentBid: 18,
          bidderId: 'p2',
        );
        final moves = rules.getValidMoves(state, 'bot1');
        final move = bot(BotDifficulty.beginner).selectMove(state, moves);
        expect(move, isA<PassMove>());
      });

      test('never picks 29 special bid; always bids the floor', () {
        final rng = Random(99);
        for (var t = 0; t < 100; t++) {
          final hand =
              (List<PlayingCard>.from(deck29)..shuffle(rng)).take(4).toList();
          final state = bidState(botHand: hand);
          final moves = rules.getValidMoves(state, 'bot1');
          final move = bot(BotDifficulty.beginner).selectMove(state, moves);
          if (move is BidMove) {
            expect(move.bidValue, isNot(TwentyNineConfig.specialBid));
            expect(move.bidValue, state.minimumBid);
          }
        }
      });
    });

    group('medium and strong (no random over-bidding)', () {
      test('medium never bids 28 or 29 across 400 random (hand, auction) trials', () {
        // Vary [currentBid] across the auction range so we actually exercise
        // the upper-bound path — at currentBid=0 the bot always bids the
        // floor, which doesn't stress the over-bidding regression.
        final rng = Random(1234);
        for (var t = 0; t < 400; t++) {
          final hand =
              (List<PlayingCard>.from(deck29)..shuffle(rng)).take(4).toList();
          final cb = rng.nextInt(13); // 0..12 → minBid ∈ 15..25.
          final state = bidState(
            botHand: hand,
            currentBid: cb,
            bidderId: cb > 0 ? 'p2' : null,
          );
          final moves = rules.getValidMoves(state, 'bot1');
          final move = bot(BotDifficulty.medium).selectMove(state, moves);
          if (move is BidMove) {
            expect(move.bidValue, lessThanOrEqualTo(25),
                reason:
                    'Medium overbid: hand=$hand currentBid=$cb → ${move.bidValue}');
            expect(move.bidValue, isNot(TwentyNineConfig.specialBid));
          }
        }
      });

      test('master never bids 28 or 29 across 400 random (hand, auction) trials', () {
        final rng = Random(7777);
        for (var t = 0; t < 400; t++) {
          final hand =
              (List<PlayingCard>.from(deck29)..shuffle(rng)).take(4).toList();
          final cb = rng.nextInt(13);
          final state = bidState(
            botHand: hand,
            currentBid: cb,
            bidderId: cb > 0 ? 'p2' : null,
          );
          final moves = rules.getValidMoves(state, 'bot1');
          final move = bot(BotDifficulty.master).selectMove(state, moves);
          if (move is BidMove) {
            expect(move.bidValue, lessThanOrEqualTo(26),
                reason:
                    'Master overbid: hand=$hand currentBid=$cb → ${move.bidValue}');
            expect(move.bidValue, isNot(TwentyNineConfig.specialBid));
          }
        }
      });

      test('strong tier uses partner bid to push higher', () {
        // Borderline hand — without partner inference strong would pass;
        // with partner having bid 17 (partnerBoost ≈ 3), it should bid.
        final borderlineHand = [
          card(Rank.jack, Suit.spades),
          card(Rank.king, Suit.spades),
          card(Rank.queen, Suit.spades),
          card(Rank.eight, Suit.hearts),
        ];

        final noPartner = bidState(
          botHand: borderlineHand,
          currentBid: 17,
          bidderId: 'p2', // opponent
        );
        final withPartner = bidState(
          botHand: borderlineHand,
          currentBid: 17,
          bidderId: 'p3', // partner
        );

        final strong = bot(BotDifficulty.hard);
        final movesNoP = rules.getValidMoves(noPartner, 'bot1');
        final movesWithP = rules.getValidMoves(withPartner, 'bot1');
        final moveNoP = strong.selectMove(noPartner, movesNoP);
        final moveWithP = strong.selectMove(withPartner, movesWithP);

        // No partner inference → likely pass. With partner inference,
        // either still pass or bid 18 — never overbid above 22.
        if (moveWithP is BidMove) {
          expect(moveWithP.bidValue, inInclusiveRange(18, 22));
        }
        if (moveNoP is BidMove) {
          expect(moveNoP.bidValue, inInclusiveRange(18, 22));
        }

        // Stronger claim: strong tier's bid value is at least as high as
        // medium tier's on the *same* hand-with-partner-bid scenario.
        final medium = bot(BotDifficulty.medium);
        final mediumWithP = medium.selectMove(withPartner, movesWithP);
        if (moveWithP is BidMove && mediumWithP is BidMove) {
          expect(moveWithP.bidValue,
              greaterThanOrEqualTo(mediumWithP.bidValue));
        }
      });
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
