// Tests for OhHellRules covering:
//   • Bug B regression surface: rules engine emits OhHellBidMove / OhHellPlayCardMove
//     with the same field names (bid, card) the bot_move_controller now consumes
//     when building the snake_case payload (bid_value / card).
//   • Initial state shape, dealer rotation, bidding turn order.
//   • forbiddenBidForDealer guard (validateMove → 'FORBIDDEN_BID').
//   • Player-count constants live on OhHellConfig.
//   • Trick play: must-follow-suit and trump-beats-non-trump.

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';

void main() {
  late OhHellRules rules;
  final playerIds = const ['p1', 'p2', 'p3', 'p4'];

  setUp(() {
    rules = OhHellRules();
  });

  // ── Initial State ─────────────────────────────────────────────────────────

  group('Initial State', () {
    test('phase is bidding', () {
      final state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );
      expect(state.phase, GamePhase.bidding);
    });

    test('each player hand has cardsThisRound cards', () {
      final state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );
      // 4 players → max cards = 52 ~/ 4 = 13. roundSequence starts at 13.
      expect(state.cardsThisRound, 13);
      for (final id in playerIds) {
        expect(state.hands[id]?.size, state.cardsThisRound);
      }
    });

    test('firstBidder is dealer+1 (left of dealer)', () {
      // dealerIndex 0 → first bidder p2
      final s0 = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );
      expect(s0.currentPlayerId, 'p2');

      // dealerIndex 2 → first bidder p4
      final s2 = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 2,
      );
      expect(s2.currentPlayerId, 'p4');

      // dealerIndex 3 (wraparound) → first bidder p1
      final s3 = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 3,
      );
      expect(s3.currentPlayerId, 'p1');
    });

    test('dealerIndex is preserved on state', () {
      final state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 1,
      );
      expect(state.dealerIndex, 1);
    });

    test('initial bids map is empty and tricksWon are all zero', () {
      final state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );
      expect(state.bids, isEmpty);
      for (final id in playerIds) {
        expect(state.tricksWon[id], 0);
        expect(state.scores[id], 0);
      }
    });
  });

  // ── Bidding Flow ──────────────────────────────────────────────────────────

  group('Bidding Flow', () {
    test('applyMove(OhHellBidMove) rotates currentPlayerId by +1', () {
      var state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );
      // p2 bids first
      expect(state.currentPlayerId, 'p2');

      final r1 = rules.applyMove(state, OhHellBidMove(playerId: 'p2', bid: 0));
      expect(r1.isValid, isTrue);
      state = r1.newState;
      expect(state.currentPlayerId, 'p3');
      expect(state.bids['p2'], 0);

      final r2 = rules.applyMove(state, OhHellBidMove(playerId: 'p3', bid: 0));
      expect(r2.isValid, isTrue);
      state = r2.newState;
      expect(state.currentPlayerId, 'p4');
    });

    test('after N bids phase=playing and currentPlayerId = dealer+1', () {
      var state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );

      // Use bids that won't be forbidden for the dealer (p1).
      // After p2=0, p3=0, p4=0, sum=0, forbidden for dealer = cardsThisRound - 0 = 13.
      // dealer bidding 1 is fine.
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p2', bid: 0)).newState;
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p3', bid: 0)).newState;
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p4', bid: 0)).newState;
      // dealer p1
      expect(state.currentPlayerId, 'p1');
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p1', bid: 1)).newState;

      expect(state.phase, GamePhase.playing);
      // dealer+1 (p2) leads first trick.
      expect(state.currentPlayerId, 'p2');
      expect(state.bids.length, 4);
    });
  });

  // ── Forbidden bid for dealer ───────────────────────────────────────────────

  group('Forbidden bid for dealer', () {
    test('dealer cannot bid the value that makes total == cardsThisRound', () {
      var state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );
      // cardsThisRound = 13. We want dealer's forbidden bid to be a
      // realistic, in-range number. After 3 bids of 4, sum = 12, so the
      // dealer (p1) cannot bid 1 (12 + 1 == 13).
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p2', bid: 4)).newState;
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p3', bid: 4)).newState;
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p4', bid: 4)).newState;

      expect(state.currentPlayerId, 'p1');
      expect(state.forbiddenBidForDealer, 1);

      // Forbidden bid is rejected.
      final invalid = OhHellBidMove(playerId: 'p1', bid: 1);
      expect(rules.validateMove(state, invalid), 'FORBIDDEN_BID');

      // Adjacent values are accepted.
      expect(rules.validateMove(state, OhHellBidMove(playerId: 'p1', bid: 0)),
          isNull);
      expect(rules.validateMove(state, OhHellBidMove(playerId: 'p1', bid: 2)),
          isNull);
    });

    test('forbidden bid is excluded from getValidMoves for dealer', () {
      var state = rules.createInitialState(
        playerIds: playerIds,
        dealerIndex: 0,
      );
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p2', bid: 4)).newState;
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p3', bid: 4)).newState;
      state = rules.applyMove(state, OhHellBidMove(playerId: 'p4', bid: 4)).newState;

      final valid = rules.getValidMoves(state, 'p1').whereType<OhHellBidMove>().toList();
      final bidValues = valid.map((m) => m.bid).toSet();
      expect(bidValues.contains(1), isFalse, reason: 'forbidden bid 1 must be excluded');
      // 0 through 13 except 1 → 13 options total.
      expect(valid.length, state.cardsThisRound);
    });
  });

  // ── Player-count validation ───────────────────────────────────────────────

  group('Player-count constants', () {
    test('OhHellConfig.minPlayers == 4 and maxPlayers == 6', () {
      expect(OhHellConfig.minPlayers, 4);
      expect(OhHellConfig.maxPlayers, 6);
    });

    test('rules.minPlayers/maxPlayers reflect the config', () {
      expect(rules.minPlayers, 4);
      expect(rules.maxPlayers, 6);
    });

    test('validPlayerCounts spans 4..6 inclusive', () {
      expect(rules.validPlayerCounts, [4, 5, 6]);
    });
  });

  // ── Trick play ────────────────────────────────────────────────────────────

  group('Trick play', () {
    // Construct a controlled playing-phase state directly so trick
    // outcomes are deterministic (avoids deck shuffle).
    OhHellState buildPlayingState({
      required String currentPlayerId,
      required Map<String, Hand> hands,
      List<TrickCard> trick = const [],
      Map<String, int>? tricksWon,
    }) {
      return OhHellState(
        phase: GamePhase.playing,
        currentPlayerId: currentPlayerId,
        playerOrder: playerIds,
        dealerIndex: 0,
        hands: hands,
        currentTrick: trick,
        cardsThisRound: 4,
        roundSequenceIndex: 0,
        totalRounds: 25,
        bids: const {'p1': 1, 'p2': 1, 'p3': 1, 'p4': 0},
        tricksWon: tricksWon ?? {for (final id in playerIds) id: 0},
        scores: {for (final id in playerIds) id: 0},
      );
    }

    test('MUST_FOLLOW_SUIT when player has the lead suit', () {
      final state = buildPlayingState(
        currentPlayerId: 'p2',
        hands: {
          'p1': Hand([PlayingCard(Suit.clubs, Rank.king)]),
          'p2': Hand([
            PlayingCard(Suit.clubs, Rank.two),
            PlayingCard(Suit.diamonds, Rank.ace),
          ]),
          'p3': Hand([PlayingCard(Suit.spades, Rank.nine)]),
          'p4': Hand([PlayingCard(Suit.hearts, Rank.three)]),
        },
        trick: const [
          TrickCard(
            playerId: 'p1',
            card: PlayingCard(Suit.clubs, Rank.king),
            seatIndex: 0,
          ),
        ],
      );

      final cheating = OhHellPlayCardMove(
        playerId: 'p2',
        card: PlayingCard(Suit.diamonds, Rank.ace),
      );
      expect(rules.validateMove(state, cheating), 'MUST_FOLLOW_SUIT');

      final ok = OhHellPlayCardMove(
        playerId: 'p2',
        card: PlayingCard(Suit.clubs, Rank.two),
      );
      expect(rules.validateMove(state, ok), isNull);
    });

    test('hearts (trump) beats a higher non-trump lead', () {
      // Lead: clubs A (p1). p2 has hearts only → trump.
      // After 4 cards play, hearts holder must win.
      var state = buildPlayingState(
        currentPlayerId: 'p1',
        hands: {
          'p1': Hand([PlayingCard(Suit.clubs, Rank.ace)]),
          'p2': Hand([PlayingCard(Suit.hearts, Rank.two)]),
          'p3': Hand([PlayingCard(Suit.diamonds, Rank.king)]),
          'p4': Hand([PlayingCard(Suit.spades, Rank.queen)]),
        },
      );

      state = rules
          .applyMove(
              state,
              OhHellPlayCardMove(
                  playerId: 'p1', card: PlayingCard(Suit.clubs, Rank.ace)))
          .newState;
      state = rules
          .applyMove(
              state,
              OhHellPlayCardMove(
                  playerId: 'p2', card: PlayingCard(Suit.hearts, Rank.two)))
          .newState;
      state = rules
          .applyMove(
              state,
              OhHellPlayCardMove(
                  playerId: 'p3', card: PlayingCard(Suit.diamonds, Rank.king)))
          .newState;
      final result = rules.applyMove(
          state,
          OhHellPlayCardMove(
              playerId: 'p4', card: PlayingCard(Suit.spades, Rank.queen)));

      expect(result.isValid, isTrue);
      // p2 won via lone trump; tricksWon[p2] should now be 1.
      expect(result.newState.tricksWon['p2'], 1);
      expect(result.newState.tricksWon['p1'], 0);
      expect(result.newState.tricksWon['p3'], 0);
      expect(result.newState.tricksWon['p4'], 0);
      // Trick winner leads next.
      expect(result.newState.currentPlayerId, 'p2');
    });

    test('highest-rank lead suit wins when no trump is played', () {
      var state = buildPlayingState(
        currentPlayerId: 'p1',
        hands: {
          'p1': Hand([PlayingCard(Suit.clubs, Rank.five)]),
          'p2': Hand([PlayingCard(Suit.clubs, Rank.ten)]),
          'p3': Hand([PlayingCard(Suit.clubs, Rank.king)]),
          'p4': Hand([PlayingCard(Suit.diamonds, Rank.ace)]), // off-suit, can't win
        },
      );

      state = rules.applyMove(state,
          OhHellPlayCardMove(playerId: 'p1', card: PlayingCard(Suit.clubs, Rank.five))).newState;
      state = rules.applyMove(state,
          OhHellPlayCardMove(playerId: 'p2', card: PlayingCard(Suit.clubs, Rank.ten))).newState;
      state = rules.applyMove(state,
          OhHellPlayCardMove(playerId: 'p3', card: PlayingCard(Suit.clubs, Rank.king))).newState;
      final result = rules.applyMove(state,
          OhHellPlayCardMove(playerId: 'p4', card: PlayingCard(Suit.diamonds, Rank.ace)));

      expect(result.isValid, isTrue);
      expect(result.newState.tricksWon['p3'], 1);
    });
  });
}
