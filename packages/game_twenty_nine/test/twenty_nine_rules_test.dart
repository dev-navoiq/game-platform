// This file is generated from 03-testing-strategy.md — it documents the
// intended contract for TwentyNineRules BEFORE the implementation is written
// (test-first per Session 3).  Tests will compile once game_twenty_nine is
// implemented; stubs are left as skip() until then.

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

  // ── Initial State ─────────────────────────────────────────────────────────

  group('Initial State', () {
    test('phase is bidding', () {
      expect(initialState.phase, GamePhase.bidding);
    });

    test('each player has 8 cards', () {
      for (final id in playerIds) {
        expect(initialState.hands[id]?.size, 8);
      }
    });

    test('first bidder is player left of dealer (p2)', () {
      expect(initialState.currentPlayerId, 'p2');
    });

    test('no trump declared at start', () {
      expect(initialState.trumpSuit, isNull);
      expect(initialState.trumpRevealed, isFalse);
    });
  });

  // ── Bidding Phase ─────────────────────────────────────────────────────────

  group('Bidding Phase', () {
    test('valid bid in range is accepted', () {
      final move = BidMove(playerId: 'p2', bidValue: 16);
      expect(rules.validateMove(initialState, move), isNull);
    });

    test('bid below minimum (< 16) is rejected', () {
      final move = BidMove(playerId: 'p2', bidValue: 14);
      expect(rules.validateMove(initialState, move), 'BID_TOO_LOW');
    });

    test('bid above 29 is rejected', () {
      final move = BidMove(playerId: 'p2', bidValue: 30);
      expect(rules.validateMove(initialState, move), 'BID_TOO_HIGH');
    });

    test('special bid of 29 is accepted', () {
      final move = BidMove(playerId: 'p2', bidValue: 29);
      expect(rules.validateMove(initialState, move), isNull);
    });

    test('move from wrong player is rejected', () {
      final move = BidMove(playerId: 'p1', bidValue: 16);
      expect(rules.validateMove(initialState, move), 'NOT_YOUR_TURN');
    });

    test('valid bid advances turn to next player', () {
      final result = rules.applyMove(
        initialState,
        BidMove(playerId: 'p2', bidValue: 16),
      );
      expect(result.isValid, isTrue);
      expect(result.newState.currentPlayerId, 'p3');
      expect(result.newState.currentBid, 16);
      expect(result.newState.bidderId, 'p2');
    });

    test('3 passes after a bid transition to trump selection', () {
      var state = initialState;
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 16)).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;

      expect(state.phase, GamePhase.trumpSelection);
      expect(state.bidderId, 'p2');
      // Bid winner picks trump themselves.
      expect(state.trumpSelector, 'p2');
    });
  });

  // ── Trump Selection Phase ─────────────────────────────────────────────────

  group('Trump Selection Phase', () {
    late TwentyNineState trumpState;

    setUp(() {
      var s = initialState;
      s = rules.applyMove(s, BidMove(playerId: 'p2', bidValue: 16)).newState;
      s = rules.applyMove(s, PassMove(playerId: 'p3')).newState;
      s = rules.applyMove(s, PassMove(playerId: 'p4')).newState;
      s = rules.applyMove(s, PassMove(playerId: 'p1')).newState;
      trumpState = s;
    });

    test('only trump selector can declare trump', () {
      final invalidMove = DeclareTrumpMove(playerId: 'p4', suit: Suit.hearts);
      expect(rules.validateMove(trumpState, invalidMove), isNotNull);

      final hand = trumpState.hands['p2']!;
      final validSuit = hand.cards.first.suit;
      final validMove = DeclareTrumpMove(playerId: 'p2', suit: validSuit);
      expect(rules.validateMove(trumpState, validMove), isNull);
    });

    test('declaring a suit not in hand is rejected', () {
      final hand = trumpState.hands['p2']!;
      final suits = hand.cards.map((c) => c.suit).toSet();
      final missingSuit = Suit.values.firstWhereOrNull((s) => !suits.contains(s));

      if (missingSuit != null) {
        final move = DeclareTrumpMove(playerId: 'p2', suit: missingSuit);
        expect(rules.validateMove(trumpState, move), 'NO_CARDS_OF_SUIT');
      }
    });
  });

  // ── Playing Phase ─────────────────────────────────────────────────────────

  group('Playing Phase', () {
    late TwentyNineState playingState;

    setUp(() {
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
        trumpSelector: 'p2',
        dealerIndex: 0,
        playerOrder: playerIds,
      );
    });

    test('leader can play any card', () {
      final move = PlayCardMove(
        playerId: 'p1',
        card: PlayingCard(Suit.spades, Rank.jack),
      );
      expect(rules.validateMove(playingState, move), isNull);
    });

    test('must follow led suit when possible', () {
      var state = rules.applyMove(
        playingState,
        PlayCardMove(playerId: 'p1', card: PlayingCard(Suit.hearts, Rank.ace)),
      ).newState;

      final invalid = PlayCardMove(
        playerId: 'p2',
        card: PlayingCard(Suit.diamonds, Rank.nine), // p2 has hearts
      );
      expect(rules.validateMove(state, invalid), 'MUST_FOLLOW_SUIT');

      final valid = PlayCardMove(
        playerId: 'p2',
        card: PlayingCard(Suit.hearts, Rank.queen),
      );
      expect(rules.validateMove(state, valid), isNull);
    });

    test('any card allowed when void in led suit', () {
      var state = rules.applyMove(
        playingState,
        PlayCardMove(playerId: 'p1', card: PlayingCard(Suit.hearts, Rank.ace)),
      ).newState;
      state = rules.applyMove(
        state,
        PlayCardMove(playerId: 'p2', card: PlayingCard(Suit.hearts, Rank.queen)),
      ).newState;

      // p3 has no hearts
      final move = PlayCardMove(
        playerId: 'p3',
        card: PlayingCard(Suit.clubs, Rank.ten),
      );
      expect(rules.validateMove(state, move), isNull);
    });

    test('completed trick is cleared from currentTrick', () {
      var state = playingState;
      state = rules.applyMove(state, PlayCardMove(playerId: 'p1', card: PlayingCard(Suit.hearts, Rank.ace))).newState;
      state = rules.applyMove(state, PlayCardMove(playerId: 'p2', card: PlayingCard(Suit.hearts, Rank.queen))).newState;
      state = rules.applyMove(state, PlayCardMove(playerId: 'p3', card: PlayingCard(Suit.clubs, Rank.ten))).newState;
      final result = rules.applyMove(
        state,
        PlayCardMove(playerId: 'p4', card: PlayingCard(Suit.hearts, Rank.nine)),
      );
      expect(result.newState.currentTrick, isEmpty);
    });
  });

  // ── Scoring ───────────────────────────────────────────────────────────────

  group('Scoring', () {
    test('J = 3 pts, 9 = 2 pts, A = 1 pt, 10 = 1 pt', () {
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.hearts, Rank.jack)), 3);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.spades, Rank.nine)), 2);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.clubs, Rank.ace)), 1);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.diamonds, Rank.ten)), 1);
    });

    test('K and Q score 0 pts', () {
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.hearts, Rank.king)), 0);
      expect(TwentyNineConfig.getCardPoints(PlayingCard(Suit.hearts, Rank.queen)), 0);
    });

    test('total card points in 32-card deck is 28', () {
      final deck = Deck.standard32();
      var total = 0;
      while (deck.remaining > 0) {
        total += TwentyNineConfig.getCardPoints(deck.draw()!);
      }
      expect(total, 28);
    });
  });

  // ── Game End ──────────────────────────────────────────────────────────────

  group('Game End', () {
    test('game ends when team reaches 6 game-points', () {
      final state = TwentyNineState(
        phase: GamePhase.gameEnd,
        sessionScores: {0: 6, 1: 4},
        hands: {},
        dealerIndex: 0,
        playerOrder: playerIds,
      );
      expect(rules.isGameOver(state), isTrue);
    });

    test('winners are the team with 6 game-points', () {
      final state = TwentyNineState(
        phase: GamePhase.gameEnd,
        sessionScores: {0: 6, 1: 4},
        hands: {},
        dealerIndex: 0,
        playerOrder: playerIds,
      );
      // Team 0 = p1 + p3
      expect(rules.getWinners(state), containsAll(['p1', 'p3']));
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('all players passing triggers redeal flag', () {
      var state = initialState;
      state = rules.applyMove(state, PassMove(playerId: 'p2')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;
      expect(state.allPlayersPassed, isTrue);
    });

    test('29 special bid records correctly', () {
      final state = rules.applyMove(
        initialState,
        BidMove(playerId: 'p2', bidValue: 29),
      ).newState;
      expect(state.currentBid, 29);
    });
  });
}
