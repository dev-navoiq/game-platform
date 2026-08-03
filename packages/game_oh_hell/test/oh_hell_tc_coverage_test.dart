// Executable coverage for the documented engine-level test cases that had
// no automated home. Each test names the TC issue it satisfies, so the
// GitHub records can point here as their evidence.
//
//   TC-OH-INIT-01 (#58)   TC-OH-INIT-02 (#59)
//   TC-OH-BID-06  (#65)   TC-OH-BID-09  (#68)  TC-OH-BID-10 (#69)
//   TC-OH-BID-02  (#141)  TC-OH-BID-03  (#142) TC-OH-BID-04 (#143)
//   TC-OH-BID-05  (#144)
//   TC-OH-PLAY-09 (#145)  TC-OH-PLAY-10 (#146) TC-OH-PLAY-11 (#147)
//   TC-OH-ROUND-01 (#151) TC-OH-ROUND-02 (#152) TC-OH-ROUND-03 (#153)
//   TC-OH-END-01  (#154)  TC-OH-END-02  (#155)

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';

void main() {
  late OhHellRules rules;
  final playerIds = const ['p1', 'p2', 'p3', 'p4'];

  setUp(() {
    rules = OhHellRules();
  });

  /// Controlled playing-phase state (mirrors oh_hell_rules_test.dart).
  OhHellState buildPlayingState({
    required String currentPlayerId,
    required Map<String, Hand> hands,
    List<TrickCard> trick = const [],
    Map<String, int>? tricksWon,
    Map<String, int>? scores,
    Map<String, int>? bids,
    int cardsThisRound = 1,
    int roundSequenceIndex = 0,
    List<int> roundSequence = const [1],
    int roundNumber = 1,
    int dealerIndex = 0,
  }) {
    return OhHellState(
      phase: GamePhase.playing,
      currentPlayerId: currentPlayerId,
      playerOrder: playerIds,
      dealerIndex: dealerIndex,
      hands: hands,
      currentTrick: trick,
      cardsThisRound: cardsThisRound,
      roundSequenceIndex: roundSequenceIndex,
      roundSequence: roundSequence,
      totalRounds: roundSequence.length,
      roundNumber: roundNumber,
      bids: bids ?? const {'p1': 0, 'p2': 1, 'p3': 0, 'p4': 0},
      tricksWon: tricksWon ?? {for (final id in playerIds) id: 0},
      scores: scores ?? {for (final id in playerIds) id: 0},
    );
  }

  group('TC-OH-INIT (#58, #59)', () {
    test('#58 create game with 4 players: 13 cards, 25 rounds, bidding', () {
      final s = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      expect(s.phase, GamePhase.bidding);
      expect(s.playerOrder, playerIds);
      expect(s.cardsThisRound, 13);
      expect(s.totalRounds, 25);
      for (final id in playerIds) {
        expect(s.hands[id]?.size, 13);
      }
      expect(s.currentPlayerId, 'p2'); // left of dealer bids first
    });

    test('#59 create game with 6 players: 8 cards, 15 rounds', () {
      final six = ['a', 'b', 'c', 'd', 'e', 'f'];
      final s = rules.createInitialState(playerIds: six, dealerIndex: 0);
      expect(s.cardsThisRound, 8); // 52 ~/ 6
      expect(s.totalRounds, 15); // 8..1..8
      for (final id in six) {
        expect(s.hands[id]?.size, 8);
      }
    });
  });

  group('TC-OH-BID validation (#65, #68, #69, #141, #142, #143, #144)', () {
    test('#141 bid below zero rejected BID_TOO_LOW', () {
      final s = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      expect(rules.validateMove(s, OhHellBidMove(playerId: 'p2', bid: -1)),
          'BID_TOO_LOW');
    });

    test('#142 bid above cardsThisRound rejected BID_TOO_HIGH', () {
      final s = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      expect(rules.validateMove(s, OhHellBidMove(playerId: 'p2', bid: 14)),
          'BID_TOO_HIGH');
    });

    test('#68 bid out of turn rejected NOT_YOUR_TURN', () {
      final s = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      // p2 is up; p3 tries to jump in.
      expect(rules.validateMove(s, OhHellBidMove(playerId: 'p3', bid: 1)),
          'NOT_YOUR_TURN');
    });

    test('#69 bid during playing phase rejected NOT_BIDDING_PHASE', () {
      final s = buildPlayingState(
        currentPlayerId: 'p1',
        hands: {'p1': Hand([PlayingCard(Suit.clubs, Rank.ace)])},
      );
      expect(rules.validateMove(s, OhHellBidMove(playerId: 'p1', bid: 1)),
          'NOT_BIDDING_PHASE');
    });

    test('#143/#65 dealer forbidden bid rejected; adjacent values accepted',
        () {
      var s = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      s = rules.applyMove(s, OhHellBidMove(playerId: 'p2', bid: 4)).newState;
      s = rules.applyMove(s, OhHellBidMove(playerId: 'p3', bid: 4)).newState;
      s = rules.applyMove(s, OhHellBidMove(playerId: 'p4', bid: 4)).newState;
      // Dealer p1 cannot make the total equal 13 (forbidden = 1)…
      expect(rules.validateMove(s, OhHellBidMove(playerId: 'p1', bid: 1)),
          'FORBIDDEN_BID');
      // …but any non-forbidden value is fine (#65).
      expect(
          rules.validateMove(s, OhHellBidMove(playerId: 'p1', bid: 0)), isNull);
      expect(
          rules.validateMove(s, OhHellBidMove(playerId: 'p1', bid: 2)), isNull);
    });

    test('#144 forbidden-bid rule never applies to non-dealers', () {
      final s = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      // First bidder p2 may bid the full round size (total == cardsThisRound
      // is only forbidden for the dealer's closing bid).
      expect(s.forbiddenBidForDealer, -1);
      expect(rules.validateMove(s, OhHellBidMove(playerId: 'p2', bid: 13)),
          isNull);
    });
  });

  group('TC-OH-PLAY validation (#145, #146, #147)', () {
    test('#145 card not in hand rejected CARD_NOT_IN_HAND', () {
      final s = buildPlayingState(
        currentPlayerId: 'p1',
        hands: {'p1': Hand([PlayingCard(Suit.clubs, Rank.two)])},
      );
      expect(
          rules.validateMove(
              s,
              OhHellPlayCardMove(
                  playerId: 'p1', card: PlayingCard(Suit.spades, Rank.king))),
          'CARD_NOT_IN_HAND');
    });

    test('#146 play during bidding phase rejected NOT_PLAYING_PHASE', () {
      final s = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      final anyCard = s.hands['p2']!.cards.first;
      expect(
          rules.validateMove(
              s, OhHellPlayCardMove(playerId: 'p2', card: anyCard)),
          'NOT_PLAYING_PHASE');
    });

    test('#147 getValidMoves returns only follow-suit-legal cards', () {
      final s = buildPlayingState(
        currentPlayerId: 'p2',
        cardsThisRound: 2,
        roundSequence: const [2],
        hands: {
          'p1': Hand([PlayingCard(Suit.clubs, Rank.king)]),
          'p2': Hand([
            PlayingCard(Suit.clubs, Rank.two),
            PlayingCard(Suit.diamonds, Rank.ace),
          ]),
        },
        trick: const [
          TrickCard(
            playerId: 'p1',
            card: PlayingCard(Suit.clubs, Rank.king),
            seatIndex: 0,
          ),
        ],
      );
      final moves =
          rules.getValidMoves(s, 'p2').whereType<OhHellPlayCardMove>().toList();
      expect(moves.map((m) => m.card).toList(),
          [PlayingCard(Suit.clubs, Rank.two)]);
      // And nothing for a player whose turn it is not.
      expect(rules.getValidMoves(s, 'p1'), isEmpty);
    });
  });

  group('TC-OH-ROUND lifecycle (#151, #152, #153)', () {
    /// One-card round with a two-round sequence: play the single trick to
    /// complete round 1.
    OhHellState completedFirstRound() {
      var s = buildPlayingState(
        currentPlayerId: 'p1',
        roundSequence: const [1, 1],
        bids: const {'p1': 1, 'p2': 0, 'p3': 0, 'p4': 0},
        hands: {
          'p1': Hand([PlayingCard(Suit.clubs, Rank.ace)]),
          'p2': Hand([PlayingCard(Suit.clubs, Rank.two)]),
          'p3': Hand([PlayingCard(Suit.diamonds, Rank.king)]),
          'p4': Hand([PlayingCard(Suit.spades, Rank.queen)]),
        },
      );
      for (final play in [
        ('p1', PlayingCard(Suit.clubs, Rank.ace)),
        ('p2', PlayingCard(Suit.clubs, Rank.two)),
        ('p3', PlayingCard(Suit.diamonds, Rank.king)),
        ('p4', PlayingCard(Suit.spades, Rank.queen)),
      ]) {
        s = rules
            .applyMove(s, OhHellPlayCardMove(playerId: play.$1, card: play.$2))
            .newState;
      }
      return s;
    }

    test('#151 round completion pauses in roundEnd with scores + history', () {
      final s = completedFirstRound();
      expect(s.phase, GamePhase.roundEnd);
      // p1 bid 1 and won the trick (ace of clubs, no trump played): 10+11×1.
      expect(s.scores['p1'], 21);
      expect(s.roundHistory.length, 1);
      expect(s.roundHistory.single['p1'], 21);
      expect(s.tricksWon['p1'], 1, reason: 'scoreboard state preserved');
      expect(s.roundSequenceIndex, 1);
    });

    test('#152 applyNewRound rotates dealer and deals the next round', () {
      final next = rules.applyNewRound(completedFirstRound());
      expect(next.phase, GamePhase.bidding);
      expect(next.dealerIndex, 1, reason: 'dealer rotates left');
      expect(next.cardsThisRound, 1);
      expect(next.bids, isEmpty);
      expect(next.tricksWon.values.every((w) => w == 0), isTrue);
      expect(next.scores['p1'], 21, reason: 'cumulative scores carry over');
      expect(next.currentPlayerId, 'p3', reason: 'left of new dealer bids');
    });

    test('#153 applyNewRound is a no-op outside roundEnd/gameEnd', () {
      final bidding =
          rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
      expect(identical(rules.applyNewRound(bidding), bidding), isTrue);
      final playing = buildPlayingState(
        currentPlayerId: 'p1',
        hands: {'p1': Hand([PlayingCard(Suit.clubs, Rank.ace)])},
      );
      expect(identical(rules.applyNewRound(playing), playing), isTrue);
    });
  });

  group('TC-OH-END lifecycle (#154, #155)', () {
    OhHellState finishedGame() {
      var s = buildPlayingState(
        currentPlayerId: 'p1',
        roundSequence: const [1],
        bids: const {'p1': 1, 'p2': 0, 'p3': 0, 'p4': 0},
        hands: {
          'p1': Hand([PlayingCard(Suit.clubs, Rank.ace)]),
          'p2': Hand([PlayingCard(Suit.clubs, Rank.two)]),
          'p3': Hand([PlayingCard(Suit.diamonds, Rank.king)]),
          'p4': Hand([PlayingCard(Suit.spades, Rank.queen)]),
        },
      );
      for (final play in [
        ('p1', PlayingCard(Suit.clubs, Rank.ace)),
        ('p2', PlayingCard(Suit.clubs, Rank.two)),
        ('p3', PlayingCard(Suit.diamonds, Rank.king)),
        ('p4', PlayingCard(Suit.spades, Rank.queen)),
      ]) {
        s = rules
            .applyMove(s, OhHellPlayCardMove(playerId: play.$1, card: play.$2))
            .newState;
      }
      return s;
    }

    test('#154 completing the final round ends the game', () {
      final s = finishedGame();
      expect(s.phase, GamePhase.gameEnd);
      expect(s.scores['p1'], 21);
      expect(s.roundHistory.length, 1);
    });

    test('#155 restart from gameEnd resets scores and sequence, keeps dealer',
        () {
      final again = rules.applyNewRound(finishedGame());
      expect(again.phase, GamePhase.bidding);
      expect(again.scores.values.every((v) => v == 0), isTrue);
      expect(again.roundSequenceIndex, 0);
      expect(again.roundNumber, 1);
      expect(again.roundHistory, isEmpty);
      expect(again.dealerIndex, 0, reason: 'dealer unchanged on restart');
    });
  });
}
