import 'dart:math';

import 'package:bot_strategies/bot_strategies.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';
import 'package:test/test.dart';

void main() {
  final rules = BridgeRules();

  // Use BotDifficulty.master so shouldPlayOptimally() is deterministic (1.0).
  BridgeBot makeBot(String playerId) => BridgeBot(
        playerId: playerId,
        name: 'TestBot',
        difficulty: BotDifficulty.master,
        random: Random(42),
      );

  // ──────────────────────────────────────────────────────────────────────────
  // HCP counting helper
  // ──────────────────────────────────────────────────────────────────────────

  group('HCP counting', () {
    test('empty hand = 0 HCP', () {
      expect(BridgeBot.hcpOfHand(Hand(const [])), 0);
    });

    test('four aces = 16 HCP', () {
      final hand = Hand([
        const PlayingCard(Suit.spades, Rank.ace),
        const PlayingCard(Suit.hearts, Rank.ace),
        const PlayingCard(Suit.clubs, Rank.ace),
        const PlayingCard(Suit.diamonds, Rank.ace),
      ]);
      expect(BridgeBot.hcpOfHand(hand), 16);
    });

    test('AKQJ = 10 HCP', () {
      final hand = Hand([
        const PlayingCard(Suit.spades, Rank.ace),
        const PlayingCard(Suit.spades, Rank.king),
        const PlayingCard(Suit.spades, Rank.queen),
        const PlayingCard(Suit.spades, Rank.jack),
      ]);
      expect(BridgeBot.hcpOfHand(hand), 10);
    });

    test('only spot cards = 0 HCP', () {
      final hand = Hand([
        const PlayingCard(Suit.spades, Rank.two),
        const PlayingCard(Suit.spades, Rank.ten),
        const PlayingCard(Suit.hearts, Rank.nine),
      ]);
      expect(BridgeBot.hcpOfHand(hand), 0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Opening bids
  // ──────────────────────────────────────────────────────────────────────────

  group('Opening bids', () {
    test('passes with fewer than 11 HCP and no preempt', () {
      final hand = _hand([
        // 4 HCP, balanced
        _c(Suit.spades, [Rank.king, Rank.three, Rank.two]),
        _c(Suit.hearts, [Rank.jack, Rank.five, Rank.four]),
        _c(Suit.diamonds, [Rank.eight, Rank.seven, Rank.six, Rank.three]),
        _c(Suit.clubs, [Rank.nine, Rank.six, Rank.two]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final moves = rules.getValidMoves(state, 'p0');
      final move = bot.selectMove(state, moves);
      expect(move, isA<BridgePassMove>());
    });

    test('opens 1NT with 15-17 balanced', () {
      // 16 HCP, 4-3-3-3
      final hand = _hand([
        _c(Suit.spades, [Rank.ace, Rank.king, Rank.four, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.eight, Rank.seven]),
        _c(Suit.diamonds, [Rank.king, Rank.jack, Rank.two]),
        _c(Suit.clubs, [Rank.queen, Rank.nine, Rank.three]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.noTrump);
    });

    test('opens 2NT with 20-21 balanced', () {
      // 20 HCP, 4-3-3-3 (AKQJ + AK + KJ + Q is 22 — need exactly 20)
      // Use A-K-Q-x / A-K-x / K-x-x / K-Q-x → 9+7+3+5 = wrong.
      // 4+3+2 + 4+3 + 3 + 3 = 22 still. Try: A-K-x-x / A-x-x / A-x-x / Q-J-x
      // → 7 + 4 + 4 + 3 = 18. Need 20. A-K-Q-x / A-x-x / K-x-x / K-x-x
      // = 9 + 4 + 3 + 3 = 19. A-K-Q-x / A-K-x / x-x-x / Q-J-x = 9+7+0+3 = 19.
      // A-K-Q-x / A-K-x / K-x-x / J-x-x = 9+7+3+1 = 20.
      final hand = _hand([
        _c(Suit.spades, [Rank.ace, Rank.king, Rank.queen, Rank.three]),
        _c(Suit.hearts, [Rank.ace, Rank.king, Rank.seven]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.three]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 2);
      expect(move.denomination, BridgeDenomination.noTrump);
    });

    test('opens 2C with 22+ HCP', () {
      // 23 HCP, 4-3-3-3
      final hand = _hand([
        _c(Suit.spades, [Rank.ace, Rank.king, Rank.queen, Rank.jack]),
        _c(Suit.hearts, [Rank.ace, Rank.king, Rank.three]),
        _c(Suit.diamonds, [Rank.ace, Rank.queen, Rank.two]),
        _c(Suit.clubs, [Rank.king, Rank.nine, Rank.three]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 2);
      expect(move.denomination, BridgeDenomination.clubs);
    });

    test('opens 1 of longer major with 5-card spade suit', () {
      // 13 HCP, 5-3-3-2
      final hand = _hand([
        _c(Suit.spades, [Rank.ace, Rank.king, Rank.eight, Rank.five, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.four]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.spades);
    });

    test('opens 1H with 5-card hearts longer than spades', () {
      // 12 HCP, 4-5-2-2
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.five, Rank.three]),
        _c(Suit.hearts, [Rank.ace, Rank.queen, Rank.nine, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.nine]),
        _c(Suit.clubs, [Rank.jack, Rank.four]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.hearts);
    });

    test('opens 1S with 5-5 majors', () {
      // 12 HCP, 5-5-2-1 (AK + QJ + K + nothing = 7+3+3 = 13... aim for 12)
      // AK853 / QJ973 / K9 / 2 = 7 + 3 + 3 + 0 = 13 HCP. Good enough (>=11).
      final hand = _hand([
        _c(Suit.spades, [Rank.ace, Rank.king, Rank.eight, Rank.five, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.jack, Rank.nine, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.four]),
        _c(Suit.clubs, [Rank.two]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.spades);
    });

    test('opens 1D with 4-4 minors and no 5-card major', () {
      // 12 HCP, 3-2-4-4
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.seven]),
        _c(Suit.diamonds, [Rank.ace, Rank.king, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.five, Rank.three]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.diamonds);
    });

    test('opens 1C with 3-3 minors and no 5-card major', () {
      // 12 HCP, 4-3-3-3 — too weak for 1NT (15-17), too strong to pass.
      // K853 / Q73 / AQx / Jxx → 3 + 2 + 6 + 1 = 12.
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.five, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.ace, Rank.queen, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.four]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.clubs);
    });

    test('opens weak 2H with 6-card heart suit and 8 HCP', () {
      // 8 HCP, 6-3-2-2 with KQ in hearts
      final hand = _hand([
        _c(Suit.spades, [Rank.eight, Rank.five, Rank.three]),
        _c(Suit.hearts,
            [Rank.king, Rank.queen, Rank.nine, Rank.seven, Rank.four, Rank.two]),
        _c(Suit.diamonds, [Rank.king, Rank.nine]),
        _c(Suit.clubs, [Rank.jack, Rank.four]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 2);
      expect(move.denomination, BridgeDenomination.hearts);
    });

    test('preempts 3S with 7-card spade suit and 8 HCP', () {
      // 8 HCP, 7-2-2-2
      final hand = _hand([
        _c(Suit.spades, [
          Rank.king,
          Rank.queen,
          Rank.ten,
          Rank.nine,
          Rank.seven,
          Rank.four,
          Rank.two
        ]),
        _c(Suit.hearts, [Rank.eight, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.nine]),
        _c(Suit.clubs, [Rank.jack, Rank.four]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 3);
      expect(move.denomination, BridgeDenomination.spades);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Responses to 1NT
  // ──────────────────────────────────────────────────────────────────────────

  group('Responses to 1NT', () {
    test('Stayman 2C with 8+ HCP and 4-card major', () {
      // Partner (seat 2) opened 1NT. We are seat 3 (next to bid).
      // 9 HCP, 4-3-3-3 with 4 hearts
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.jack, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.queen, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.noTrump), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 2);
      expect(move.denomination, BridgeDenomination.clubs);
    });

    test('Jacoby transfer 2D with 5+ hearts', () {
      // 7 HCP, 2-5-3-3
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.three]),
        _c(Suit.hearts,
            [Rank.queen, Rank.jack, Rank.nine, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.eight, Rank.six, Rank.two]),
        _c(Suit.clubs, [Rank.nine, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.noTrump), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 2);
      expect(move.denomination, BridgeDenomination.diamonds);
    });

    test('Jacoby transfer 2H with 5+ spades', () {
      // 8 HCP, 5-2-3-3
      final hand = _hand([
        _c(Suit.spades,
            [Rank.king, Rank.jack, Rank.nine, Rank.seven, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.six, Rank.two]),
        _c(Suit.clubs, [Rank.nine, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.noTrump), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 2);
      expect(move.denomination, BridgeDenomination.hearts);
    });

    test('3NT game with 10-15 HCP, balanced, no 4-card major', () {
      // 12 HCP, 3-3-4-3
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.ace, Rank.jack, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.king, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.noTrump), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 3);
      expect(move.denomination, BridgeDenomination.noTrump);
    });

    test('passes with less than 8 HCP and no 5-card major', () {
      // 4 HCP, 3-3-4-3
      final hand = _hand([
        _c(Suit.spades, [Rank.eight, Rank.six, Rank.three]),
        _c(Suit.hearts, [Rank.jack, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.eight, Rank.six, Rank.two]),
        _c(Suit.clubs, [Rank.nine, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.noTrump), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p0'));
      expect(move, isA<BridgePassMove>());
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Responses to major opening
  // ──────────────────────────────────────────────────────────────────────────

  group('Responses to 1 of a major', () {
    test('simple raise 2H with 6-9 HCP and 3+ hearts', () {
      // 8 HCP, 3-3-4-3
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.jack, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.nine, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.hearts), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 2);
      expect(move.denomination, BridgeDenomination.hearts);
    });

    test('limit raise 3H with 10-12 HCP and 3+ hearts', () {
      // 11 HCP, 3-4-3-3
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.jack, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.queen, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.hearts), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 3);
      expect(move.denomination, BridgeDenomination.hearts);
    });

    test('1S over 1H with 4+ spades and 6+ HCP', () {
      // 9 HCP, 4-2-4-3
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.jack, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.queen, Rank.nine, Rank.six, Rank.two]),
        _c(Suit.clubs, [Rank.king, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.hearts), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p0')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.spades);
    });

    test('passes with fewer than 6 HCP', () {
      // 3 HCP, 3-3-4-3
      final hand = _hand([
        _c(Suit.spades, [Rank.eight, Rank.six, Rank.three]),
        _c(Suit.hearts, [Rank.jack, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.nine, Rank.eight, Rank.six, Rank.two]),
        _c(Suit.clubs, [Rank.queen, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 0,
          history: [_call(2, 'bid', 1, BridgeDenomination.hearts), _call(3, 'pass')]);
      final bot = makeBot('p0');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p0'));
      expect(move, isA<BridgePassMove>());
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Competitive bidding
  // ──────────────────────────────────────────────────────────────────────────

  group('Competitive bidding', () {
    test('takeout double over 1D with 13 HCP and shortness in diamonds', () {
      // 13 HCP, 4-4-1-4 (singleton diamond, support in unbid suits)
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.jack, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.ace, Rank.queen, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.four]),
        _c(Suit.clubs, [Rank.king, Rank.nine, Rank.six, Rank.three]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 1,
          history: [_call(0, 'bid', 1, BridgeDenomination.diamonds)]);
      final bot = makeBot('p1');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p1'));
      expect(move, isA<BridgeDoubleMove>());
    });

    test('1S overcall over 1H with 5+ spades and 10 HCP', () {
      // 10 HCP, 5-3-3-2 with KQJxx of spades
      final hand = _hand([
        _c(Suit.spades,
            [Rank.king, Rank.queen, Rank.jack, Rank.eight, Rank.three]),
        _c(Suit.hearts, [Rank.seven, Rank.five, Rank.three]),
        _c(Suit.diamonds, [Rank.queen, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.nine, Rank.six]),
      ]);
      final state = _stateAfterAuction(hand,
          biddingSeat: 1,
          history: [_call(0, 'bid', 1, BridgeDenomination.hearts)]);
      final bot = makeBot('p1');
      final move =
          bot.selectMove(state, rules.getValidMoves(state, 'p1')) as BridgeBidMove;
      expect(move.level, 1);
      expect(move.denomination, BridgeDenomination.spades);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Card play — opening lead
  // ──────────────────────────────────────────────────────────────────────────

  group('Opening lead', () {
    test('leads top of KQJ sequence vs NT', () {
      // We're on lead vs 3NT
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.queen, Rank.jack, Rank.three]),
        _c(Suit.hearts, [Rank.seven, Rank.five]),
        _c(Suit.diamonds, [Rank.queen, Rank.nine, Rank.eight, Rank.two]),
        _c(Suit.clubs, [Rank.nine, Rank.six, Rank.four]),
      ]);
      final state = _statePlayingLead(
        hand: hand,
        leaderSeat: 0,
        contract: const BridgeContract(
          level: 3,
          denomination: BridgeDenomination.noTrump,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p0');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p0'))
          as BridgePlayCardMove;
      expect(move.card, const PlayingCard(Suit.spades, Rank.king));
    });

    test('leads 4th best from longest suit vs NT (no sequence)', () {
      // 4-card diamonds KJ9x, no sequences elsewhere
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.three]),
        _c(Suit.hearts, [Rank.seven, Rank.five, Rank.two]),
        _c(Suit.diamonds, [Rank.king, Rank.jack, Rank.nine, Rank.three]),
        _c(Suit.clubs, [Rank.queen, Rank.nine, Rank.six, Rank.four]),
      ]);
      final state = _statePlayingLead(
        hand: hand,
        leaderSeat: 0,
        contract: const BridgeContract(
          level: 3,
          denomination: BridgeDenomination.noTrump,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p0');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p0'))
          as BridgePlayCardMove;
      // 4 cards in each of D and C — should pick from longest+strongest
      // (diamonds wins on strength: 4 HCP vs 2 HCP).
      // 4th best of KJ93 sorted high-to-low is 3.
      expect(move.card.suit, Suit.diamonds);
      expect(move.card.rank, Rank.three);
    });

    test('avoids leading trump vs suit contract', () {
      // 4 spades (trump), 3 hearts, 3 diamonds, 3 clubs
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.five, Rank.three]),
        _c(Suit.hearts, [Rank.nine, Rank.seven, Rank.two]),
        _c(Suit.diamonds, [Rank.queen, Rank.eight, Rank.three]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.four]),
      ]);
      final state = _statePlayingLead(
        hand: hand,
        leaderSeat: 0,
        contract: const BridgeContract(
          level: 4,
          denomination: BridgeDenomination.spades,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p0');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p0'))
          as BridgePlayCardMove;
      expect(move.card.suit, isNot(Suit.spades));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Card play — following a trick
  // ──────────────────────────────────────────────────────────────────────────

  group('Following to a trick', () {
    test('2nd hand low', () {
      // Lead was 5 of hearts by p0. We are seat 1, second to play.
      final hand = _hand([
        _c(Suit.hearts, [Rank.king, Rank.queen, Rank.seven, Rank.two]),
        _c(Suit.spades, [Rank.ace, Rank.eight]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.three]),
        _c(Suit.clubs, [Rank.queen, Rank.jack, Rank.six, Rank.four]),
      ]);
      final state = _stateMidTrick(
        myHand: hand,
        mySeat: 1,
        trick: [
          TrickCard(
              playerId: 'p0',
              card: const PlayingCard(Suit.hearts, Rank.five),
              seatIndex: 0),
        ],
        contract: const BridgeContract(
          level: 3,
          denomination: BridgeDenomination.noTrump,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p2',
          declarerSeat: 2,
        ),
      );
      final bot = makeBot('p1');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p1'))
          as BridgePlayCardMove;
      // 2nd hand low — should play 2 of hearts (lowest)
      expect(move.card, const PlayingCard(Suit.hearts, Rank.two));
    });

    test('3rd hand high — beat current winner with cheapest card', () {
      // Lead 5H from p0, p1 played 7H. We (seat 2, partner of p0) — 3rd hand.
      final hand = _hand([
        _c(Suit.hearts, [Rank.queen, Rank.nine, Rank.three]),
        _c(Suit.spades, [Rank.ace, Rank.eight]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.three, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.four, Rank.two]),
      ]);
      final state = _stateMidTrick(
        myHand: hand,
        mySeat: 2,
        trick: [
          TrickCard(
              playerId: 'p0',
              card: const PlayingCard(Suit.hearts, Rank.five),
              seatIndex: 0),
          TrickCard(
              playerId: 'p1',
              card: const PlayingCard(Suit.hearts, Rank.seven),
              seatIndex: 1),
        ],
        contract: const BridgeContract(
          level: 3,
          denomination: BridgeDenomination.noTrump,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p2');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p2'))
          as BridgePlayCardMove;
      // Cheapest card that beats 7H is 9H.
      expect(move.card, const PlayingCard(Suit.hearts, Rank.nine));
    });

    test('3rd hand low when partner is already winning', () {
      // p0 (partner) led KH, p1 played 4H. We are seat 2.
      final hand = _hand([
        _c(Suit.hearts, [Rank.queen, Rank.nine, Rank.three, Rank.two]),
        _c(Suit.spades, [Rank.ace, Rank.eight]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.three]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.four, Rank.two]),
      ]);
      final state = _stateMidTrick(
        myHand: hand,
        mySeat: 2,
        trick: [
          TrickCard(
              playerId: 'p0',
              card: const PlayingCard(Suit.hearts, Rank.king),
              seatIndex: 0),
          TrickCard(
              playerId: 'p1',
              card: const PlayingCard(Suit.hearts, Rank.four),
              seatIndex: 1),
        ],
        contract: const BridgeContract(
          level: 3,
          denomination: BridgeDenomination.noTrump,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p2');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p2'))
          as BridgePlayCardMove;
      // Partner winning — play low. Cheapest hearts = 2.
      expect(move.card, const PlayingCard(Suit.hearts, Rank.two));
    });

    test('ruffs when void and partner not winning', () {
      // Trump = spades. Lead was 5H from p0, p1 played AH (winning).
      // We are seat 2, void in hearts.
      final hand = _hand([
        _c(Suit.spades, [Rank.queen, Rank.four, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.three, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.four, Rank.two]),
        _c(Suit.hearts, const []),
      ]);
      final state = _stateMidTrick(
        myHand: hand,
        mySeat: 2,
        trick: [
          TrickCard(
              playerId: 'p0',
              card: const PlayingCard(Suit.hearts, Rank.five),
              seatIndex: 0),
          TrickCard(
              playerId: 'p1',
              card: const PlayingCard(Suit.hearts, Rank.ace),
              seatIndex: 1),
        ],
        contract: const BridgeContract(
          level: 4,
          denomination: BridgeDenomination.spades,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p2');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p2'))
          as BridgePlayCardMove;
      // Should ruff with smallest trump = 3 of spades
      expect(move.card.suit, Suit.spades);
      expect(move.card.rank, Rank.three);
    });

    test('discards from longest non-trump when out of suit and cannot help',
        () {
      // Trump = spades. Lead 5H by p0 (partner), p1 played 4H.
      // p0 already winning. We are void in hearts, seat 2.
      final hand = _hand([
        _c(Suit.spades, [Rank.queen, Rank.four]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.three, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.four]),
        _c(Suit.hearts, const []),
      ]);
      final state = _stateMidTrick(
        myHand: hand,
        mySeat: 2,
        trick: [
          TrickCard(
              playerId: 'p0',
              card: const PlayingCard(Suit.hearts, Rank.king),
              seatIndex: 0),
          TrickCard(
              playerId: 'p1',
              card: const PlayingCard(Suit.hearts, Rank.four),
              seatIndex: 1),
        ],
        contract: const BridgeContract(
          level: 4,
          denomination: BridgeDenomination.spades,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p2');
      final move = bot.selectMove(state, rules.getValidMoves(state, 'p2'))
          as BridgePlayCardMove;
      // Partner winning, no need to ruff — discard from longest non-trump
      // (diamonds, 4 cards) — smallest = 2 of diamonds.
      expect(move.card, const PlayingCard(Suit.diamonds, Rank.two));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Robustness / fallthrough
  // ──────────────────────────────────────────────────────────────────────────

  group('Robustness', () {
    test('selectMove returns null for empty move list', () {
      final hand = _hand([
        _c(Suit.spades, [Rank.ace]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      expect(bot.selectMove(state, const []), isNull);
    });

    test('always returns one of the legal moves during bidding', () {
      final hand = _hand([
        _c(Suit.spades, [Rank.king, Rank.eight, Rank.five, Rank.three]),
        _c(Suit.hearts, [Rank.queen, Rank.seven, Rank.three]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.two]),
        _c(Suit.clubs, [Rank.queen, Rank.six, Rank.three]),
      ]);
      final state = _stateBidding(hand, playerIdx: 0);
      final bot = makeBot('p0');
      final moves = rules.getValidMoves(state, 'p0');
      final move = bot.selectMove(state, moves);
      expect(moves, contains(move));
    });

    test('always returns a legal card during play', () {
      // Random reasonable hand and trick scenario; doesn't matter what.
      final hand = _hand([
        _c(Suit.hearts, [Rank.queen, Rank.nine, Rank.three]),
        _c(Suit.spades, [Rank.ace, Rank.eight]),
        _c(Suit.diamonds, [Rank.king, Rank.nine, Rank.three, Rank.two]),
        _c(Suit.clubs, [Rank.jack, Rank.six, Rank.four, Rank.two]),
      ]);
      final state = _stateMidTrick(
        myHand: hand,
        mySeat: 2,
        trick: [
          TrickCard(
              playerId: 'p0',
              card: const PlayingCard(Suit.hearts, Rank.five),
              seatIndex: 0),
          TrickCard(
              playerId: 'p1',
              card: const PlayingCard(Suit.hearts, Rank.seven),
              seatIndex: 1),
        ],
        contract: const BridgeContract(
          level: 3,
          denomination: BridgeDenomination.noTrump,
          doubleStatus: BridgeDoubleStatus.undoubled,
          declarerId: 'p1',
          declarerSeat: 1,
        ),
      );
      final bot = makeBot('p2');
      final moves = rules.getValidMoves(state, 'p2');
      final move = bot.selectMove(state, moves);
      expect(moves, contains(move));
    });

    test('isComplexDecision returns true for bids', () {
      final bot = makeBot('p0');
      final bid = BridgeBidMove(
          playerId: 'p0', level: 1, denomination: BridgeDenomination.noTrump);
      final state = _stateBidding(_hand([_c(Suit.spades, [Rank.ace])]),
          playerIdx: 0);
      expect(bot.isComplexDecision(state, bid), isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Factory wiring
  // ──────────────────────────────────────────────────────────────────────────

  group('BotFactory bridge wiring', () {
    setUp(() => BotFactory.resetNames());

    test('creates BridgeBot for game type "bridge"', () {
      final bot =
          BotFactory.createBot(gameType: 'bridge', playerId: 'b1');
      expect(bot, isA<BridgeBot>());
    });
  });
}

// ─── Test helpers ────────────────────────────────────────────────────────────

List<PlayingCard> _c(Suit suit, List<Rank> ranks) =>
    [for (final r in ranks) PlayingCard(suit, r)];

Hand _hand(List<List<PlayingCard>> groups) {
  final all = <PlayingCard>[];
  for (final g in groups) {
    all.addAll(g);
  }
  return Hand(all);
}

/// Build a BridgeState where it's [playerIdx]'s turn to bid (no prior auction).
BridgeState _stateBidding(Hand hand, {required int playerIdx}) {
  final players = ['p0', 'p1', 'p2', 'p3'];
  final hands = <String, Hand>{
    for (var i = 0; i < 4; i++)
      players[i]: i == playerIdx ? hand : Hand(const []),
  };
  return BridgeState(
    phase: GamePhase.bidding,
    currentPlayerId: players[playerIdx],
    playerOrder: players,
    dealerIndex: playerIdx,
    hands: hands,
    dealNumber: 1,
    vulnerability: Vulnerability.none,
  );
}

AuctionCall _call(int seat, String type, [int? level, BridgeDenomination? denom]) {
  return AuctionCall(
    playerId: 'p$seat',
    seatIndex: seat,
    type: type,
    level: level,
    denomination: denom,
  );
}

/// Build a BridgeState mid-auction: [history] are calls already made,
/// it's [biddingSeat]'s turn next.
BridgeState _stateAfterAuction(
  Hand hand, {
  required int biddingSeat,
  required List<AuctionCall> history,
}) {
  final players = ['p0', 'p1', 'p2', 'p3'];
  final hands = <String, Hand>{
    for (var i = 0; i < 4; i++)
      players[i]: i == biddingSeat ? hand : Hand(const []),
  };
  return BridgeState(
    phase: GamePhase.bidding,
    currentPlayerId: players[biddingSeat],
    playerOrder: players,
    dealerIndex: 0,
    hands: hands,
    dealNumber: 1,
    vulnerability: Vulnerability.none,
    auctionHistory: history,
  );
}

/// Build a BridgeState where opening lead is about to be made by [leaderSeat].
BridgeState _statePlayingLead({
  required Hand hand,
  required int leaderSeat,
  required BridgeContract contract,
}) {
  final players = ['p0', 'p1', 'p2', 'p3'];
  final hands = <String, Hand>{
    for (var i = 0; i < 4; i++)
      players[i]: i == leaderSeat ? hand : Hand(const []),
  };
  final dummySeat = (contract.declarerSeat + 2) % 4;
  return BridgeState(
    phase: GamePhase.playing,
    currentPlayerId: players[leaderSeat],
    playerOrder: players,
    dealerIndex: 0,
    hands: hands,
    dealNumber: 1,
    vulnerability: Vulnerability.none,
    contract: contract,
    dummyId: players[dummySeat],
    dummyRevealed: false,
    currentTrick: const [],
    trickNumber: 0,
  );
}

/// Build a BridgeState mid-trick: [trick] are cards already played, it's
/// [mySeat]'s turn.
BridgeState _stateMidTrick({
  required Hand myHand,
  required int mySeat,
  required List<TrickCard> trick,
  required BridgeContract contract,
}) {
  final players = ['p0', 'p1', 'p2', 'p3'];
  final hands = <String, Hand>{
    for (var i = 0; i < 4; i++)
      players[i]: i == mySeat ? myHand : Hand(const []),
  };
  final dummySeat = (contract.declarerSeat + 2) % 4;
  return BridgeState(
    phase: GamePhase.playing,
    currentPlayerId: players[mySeat],
    playerOrder: players,
    dealerIndex: 0,
    hands: hands,
    dealNumber: 1,
    vulnerability: Vulnerability.none,
    contract: contract,
    dummyId: players[dummySeat],
    dummyRevealed: true,
    currentTrick: trick,
    trickNumber: 1,
  );
}
