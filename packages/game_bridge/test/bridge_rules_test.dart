// End-to-end coverage for BridgeRules: initial deal, auction validation,
// auction termination + declarer determination, card play (must-follow-suit,
// trump winning), dummy reveal + declarer-plays-dummy, deal completion +
// scoring, multi-deal session progression, vulnerability rotation,
// game-end winner detection.

import 'package:flutter_test/flutter_test.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_core/game_core.dart';

void main() {
  late BridgeRules rules;
  const playerIds = ['p1', 'p2', 'p3', 'p4']; // seats 0=N, 1=E, 2=S, 3=W

  setUp(() {
    rules = BridgeRules();
  });

  BridgeState initialState({int dealerIndex = 0}) =>
      rules.createInitialState(playerIds: playerIds, dealerIndex: dealerIndex);

  // ── Initial state ────────────────────────────────────────────────────────

  group('Initial state', () {
    test('exactly 4 players required', () {
      expect(
        () => rules.createInitialState(
            playerIds: const ['a', 'b', 'c'], dealerIndex: 0),
        throwsArgumentError,
      );
    });

    test('phase is bidding, dealer is first to call', () {
      final s = initialState(dealerIndex: 2);
      expect(s.phase, GamePhase.bidding);
      expect(s.currentPlayerId, 'p3');
      expect(s.dealerIndex, 2);
    });

    test('each hand has 13 cards; no duplicates across hands', () {
      final s = initialState();
      final allCards = <PlayingCard>[];
      for (final pid in playerIds) {
        expect(s.hands[pid]!.size, 13);
        allCards.addAll(s.hands[pid]!.cards);
      }
      expect(allCards.length, 52);
      expect(allCards.toSet().length, 52);
    });

    test('dealNumber and vulnerability seeded for deal 1', () {
      final s = initialState();
      expect(s.dealNumber, 1);
      expect(s.vulnerability, Vulnerability.none);
      expect(s.tricksWon, {'NS': 0, 'EW': 0});
      expect(s.scores, {'NS': 0, 'EW': 0});
      expect(s.totalDeals, BridgeConfig.totalDeals);
    });

    test('vulnerability rotation Chicago: 1=none,2=NS,3=EW,4=both', () {
      expect(BridgeConfig.vulnerabilityForDeal(1), Vulnerability.none);
      expect(BridgeConfig.vulnerabilityForDeal(2), Vulnerability.ns);
      expect(BridgeConfig.vulnerabilityForDeal(3), Vulnerability.ew);
      expect(BridgeConfig.vulnerabilityForDeal(4), Vulnerability.both);
    });
  });

  // ── Auction validation ──────────────────────────────────────────────────

  group('Auction', () {
    test('pass is always legal', () {
      final s = initialState();
      expect(
        rules.validateMove(s, const BridgePassMove(playerId: 'p1')),
        isNull,
      );
    });

    test('bid out of range', () {
      final s = initialState();
      expect(
        rules.validateMove(s,
            const BridgeBidMove(playerId: 'p1', level: 0, denomination: BridgeDenomination.clubs)),
        'BID_OUT_OF_RANGE',
      );
      expect(
        rules.validateMove(s,
            const BridgeBidMove(playerId: 'p1', level: 8, denomination: BridgeDenomination.clubs)),
        'BID_OUT_OF_RANGE',
      );
    });

    test('new bid must outrank previous bid', () {
      var s = initialState();
      final r1 = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p1', level: 2, denomination: BridgeDenomination.hearts));
      s = r1.newState;
      // 2♣ is lower than 2♥ → invalid
      expect(
        rules.validateMove(s,
            const BridgeBidMove(playerId: 'p2', level: 2, denomination: BridgeDenomination.clubs)),
        'BID_TOO_LOW',
      );
      // 2♠ outranks 2♥ → valid
      expect(
        rules.validateMove(s,
            const BridgeBidMove(playerId: 'p2', level: 2, denomination: BridgeDenomination.spades)),
        isNull,
      );
      // 3♣ outranks 2♥ → valid
      expect(
        rules.validateMove(s,
            const BridgeBidMove(playerId: 'p2', level: 3, denomination: BridgeDenomination.clubs)),
        isNull,
      );
    });

    test('cannot double without a bid', () {
      final s = initialState();
      expect(
        rules.validateMove(s, const BridgeDoubleMove(playerId: 'p1')),
        'NO_BID_TO_DOUBLE',
      );
    });

    test('cannot double partner', () {
      var s = initialState();
      // p1 (seat 0, NS) bids 1NT
      s = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p1', level: 1, denomination: BridgeDenomination.noTrump)).newState;
      // p2 (seat 1, EW) passes
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p2')).newState;
      // p3 (seat 2, NS) cannot double partner's bid
      expect(
        rules.validateMove(s, const BridgeDoubleMove(playerId: 'p3')),
        'CANNOT_DOUBLE_PARTNER',
      );
    });

    test('double opponents, then redouble own side', () {
      var s = initialState();
      // p1 (NS) opens 1NT
      s = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p1', level: 1, denomination: BridgeDenomination.noTrump)).newState;
      // p2 (EW) doubles
      expect(rules.validateMove(s, const BridgeDoubleMove(playerId: 'p2')), isNull);
      s = rules.applyMove(s, const BridgeDoubleMove(playerId: 'p2')).newState;
      // p3 (NS) can redouble
      expect(rules.validateMove(s, const BridgeRedoubleMove(playerId: 'p3')), isNull);
      // p2 cannot double again (already doubled) — out of turn but also semantically
      // skip; check next: p3 redoubles → p4 cannot redouble again
      s = rules.applyMove(s, const BridgeRedoubleMove(playerId: 'p3')).newState;
      expect(
        rules.validateMove(s, const BridgeRedoubleMove(playerId: 'p4')),
        'ALREADY_REDOUBLED',
      );
    });

    test('passed out: 4 passes → roundEnd with 0 points', () {
      var s = initialState();
      for (final pid in playerIds) {
        s = rules.applyMove(s, BridgePassMove(playerId: pid)).newState;
      }
      expect(s.phase, GamePhase.roundEnd);
      expect(s.contract, isNull);
      expect(s.dealHistory.last.isPassedOut, true);
      expect(s.scores, {'NS': 0, 'EW': 0});
    });

    test('auction ends after 3 passes following a bid; declarer = first to name suit', () {
      var s = initialState();
      // Build auction: p1 (N) bids 1H, p2 (E) bids 2D, p3 (S) bids 2H,
      // p4 (W) passes, p1 passes, p2 passes → contract 2H by N (p1 named hearts first on NS).
      s = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p1', level: 1, denomination: BridgeDenomination.hearts)).newState;
      s = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p2', level: 2, denomination: BridgeDenomination.diamonds)).newState;
      s = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p3', level: 2, denomination: BridgeDenomination.hearts)).newState;
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p4')).newState;
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p1')).newState;
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p2')).newState;

      expect(s.phase, GamePhase.playing);
      expect(s.contract!.level, 2);
      expect(s.contract!.denomination, BridgeDenomination.hearts);
      expect(s.contract!.declarerId, 'p1');
      expect(s.dummyId, 'p3');
      // Opening lead from player to declarer's left = seat 1 = p2
      expect(s.currentPlayerId, 'p2');
      expect(s.contract!.doubleStatus, BridgeDoubleStatus.undoubled);
    });

    test('doubled contract preserved in settled contract', () {
      var s = initialState();
      s = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p1', level: 3, denomination: BridgeDenomination.noTrump)).newState;
      s = rules.applyMove(s, const BridgeDoubleMove(playerId: 'p2')).newState;
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p3')).newState;
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p4')).newState;
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p1')).newState;
      expect(s.phase, GamePhase.playing);
      expect(s.contract!.doubleStatus, BridgeDoubleStatus.doubled);
    });
  });

  // ── Play phase ──────────────────────────────────────────────────────────

  /// Build a state in the playing phase with a known contract by directly
  /// constructing — avoids the randomness of the auction path.
  BridgeState handcraftPlayState({
    required BridgeDenomination trump,
    required Map<String, List<PlayingCard>> hands,
    required String declarerId,
    required int declarerSeat,
    required String leaderId,
  }) {
    final dummySeat = (declarerSeat + 2) % 4;
    return BridgeState(
      phase: GamePhase.playing,
      currentPlayerId: leaderId,
      playerOrder: playerIds,
      dealerIndex: 0,
      hands: {for (final e in hands.entries) e.key: Hand(e.value)},
      dealNumber: 1,
      vulnerability: Vulnerability.none,
      contract: BridgeContract(
        level: 3,
        denomination: trump,
        doubleStatus: BridgeDoubleStatus.undoubled,
        declarerId: declarerId,
        declarerSeat: declarerSeat,
      ),
      dummyId: playerIds[dummySeat],
      trickNumber: 0,
    );
  }

  group('Play — must follow suit', () {
    test('player with lead suit must follow', () {
      final s = handcraftPlayState(
        trump: BridgeDenomination.spades,
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.ace)],
          'p2': [
            const PlayingCard(Suit.hearts, Rank.two),
            const PlayingCard(Suit.diamonds, Rank.king),
          ],
          'p3': [const PlayingCard(Suit.clubs, Rank.three)],
          'p4': [const PlayingCard(Suit.spades, Rank.four)],
        },
        declarerId: 'p4',
        declarerSeat: 3, // EW, dummy = p2 (seat 1)
        leaderId: 'p1',
      );
      // p1 leads ♥A
      var ns = rules.applyMove(s,
          BridgePlayCardMove(playerId: 'p1', card: const PlayingCard(Suit.hearts, Rank.ace))).newState;
      // p2 must play ♥2, not ♦K
      expect(
        rules.validateMove(ns,
            BridgePlayCardMove(playerId: 'p2', card: const PlayingCard(Suit.diamonds, Rank.king))),
        'MUST_FOLLOW_SUIT',
      );
      expect(
        rules.validateMove(ns,
            BridgePlayCardMove(playerId: 'p2', card: const PlayingCard(Suit.hearts, Rank.two))),
        isNull,
      );
    });

    test('player without lead suit may discard anything', () {
      final s = handcraftPlayState(
        trump: BridgeDenomination.spades,
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.ace)],
          'p2': [const PlayingCard(Suit.diamonds, Rank.king)], // no hearts
          'p3': [const PlayingCard(Suit.clubs, Rank.three)],
          'p4': [const PlayingCard(Suit.spades, Rank.four)],
        },
        declarerId: 'p4',
        declarerSeat: 3,
        leaderId: 'p1',
      );
      var ns = rules.applyMove(s,
          BridgePlayCardMove(playerId: 'p1', card: const PlayingCard(Suit.hearts, Rank.ace))).newState;
      // p2 has no ♥ → can discard ♦K
      expect(
        rules.validateMove(ns,
            BridgePlayCardMove(playerId: 'p2', card: const PlayingCard(Suit.diamonds, Rank.king))),
        isNull,
      );
    });
  });

  group('Trick winner', () {
    test('highest of lead suit wins when no trump played', () {
      final s = handcraftPlayState(
        trump: BridgeDenomination.spades,
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.ace)],
          'p2': [const PlayingCard(Suit.hearts, Rank.two)],
          'p3': [const PlayingCard(Suit.hearts, Rank.king)],
          'p4': [const PlayingCard(Suit.hearts, Rank.queen)],
        },
        declarerId: 'p4',
        declarerSeat: 3,
        leaderId: 'p1',
      );
      var ns = rules.applyMove(s,
          BridgePlayCardMove(playerId: 'p1', card: const PlayingCard(Suit.hearts, Rank.ace))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p2', card: const PlayingCard(Suit.hearts, Rank.two))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p3', card: const PlayingCard(Suit.hearts, Rank.king))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p4', card: const PlayingCard(Suit.hearts, Rank.queen))).newState;
      expect(ns.currentPlayerId, 'p1'); // p1's Ace wins
      expect(ns.tricksWon['NS'], 1);
      expect(ns.tricksWon['EW'], 0);
    });

    test('trump beats higher card of lead suit', () {
      final s = handcraftPlayState(
        trump: BridgeDenomination.spades,
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.ace)],
          'p2': [const PlayingCard(Suit.spades, Rank.two)],   // ruff
          'p3': [const PlayingCard(Suit.hearts, Rank.king)],
          'p4': [const PlayingCard(Suit.hearts, Rank.queen)],
        },
        declarerId: 'p4',
        declarerSeat: 3,
        leaderId: 'p1',
      );
      var ns = rules.applyMove(s,
          BridgePlayCardMove(playerId: 'p1', card: const PlayingCard(Suit.hearts, Rank.ace))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p2', card: const PlayingCard(Suit.spades, Rank.two))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p3', card: const PlayingCard(Suit.hearts, Rank.king))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p4', card: const PlayingCard(Suit.hearts, Rank.queen))).newState;
      expect(ns.currentPlayerId, 'p2'); // p2 ruffed
      expect(ns.tricksWon['EW'], 1);
    });

    test('NT: trump suit absent → highest of lead suit always wins', () {
      final s = handcraftPlayState(
        trump: BridgeDenomination.noTrump,
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.ace)],
          'p2': [const PlayingCard(Suit.spades, Rank.king)], // out of suit
          'p3': [const PlayingCard(Suit.hearts, Rank.king)],
          'p4': [const PlayingCard(Suit.hearts, Rank.queen)],
        },
        declarerId: 'p4',
        declarerSeat: 3,
        leaderId: 'p1',
      );
      var ns = rules.applyMove(s,
          BridgePlayCardMove(playerId: 'p1', card: const PlayingCard(Suit.hearts, Rank.ace))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p2', card: const PlayingCard(Suit.spades, Rank.king))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p3', card: const PlayingCard(Suit.hearts, Rank.king))).newState;
      ns = rules.applyMove(ns,
          BridgePlayCardMove(playerId: 'p4', card: const PlayingCard(Suit.hearts, Rank.queen))).newState;
      expect(ns.currentPlayerId, 'p1'); // ♠ doesn't trump in NT
      expect(ns.tricksWon['NS'], 1);
    });
  });

  group('Dummy', () {
    test('opening lead reveals dummy', () {
      final s = handcraftPlayState(
        trump: BridgeDenomination.spades,
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.ace)],
          'p2': [const PlayingCard(Suit.hearts, Rank.two)],
          'p3': [const PlayingCard(Suit.hearts, Rank.king)],
          'p4': [const PlayingCard(Suit.spades, Rank.four)],
        },
        declarerId: 'p4',
        declarerSeat: 3,
        leaderId: 'p1',
      );
      expect(s.dummyRevealed, false);
      final ns = rules.applyMove(s,
          BridgePlayCardMove(playerId: 'p1', card: const PlayingCard(Suit.hearts, Rank.ace))).newState;
      expect(ns.dummyRevealed, true);
    });

    test('declarer can play dummy\'s cards', () {
      // p4 = declarer (seat 3 EW), p2 = dummy (seat 1).
      // p1 leads, then it's p2 (dummy)'s turn — declarer p4 should play for p2.
      final s = handcraftPlayState(
        trump: BridgeDenomination.spades,
        hands: {
          'p1': [const PlayingCard(Suit.hearts, Rank.ace)],
          'p2': [const PlayingCard(Suit.hearts, Rank.two)],
          'p3': [const PlayingCard(Suit.hearts, Rank.king)],
          'p4': [const PlayingCard(Suit.spades, Rank.four)],
        },
        declarerId: 'p4',
        declarerSeat: 3,
        leaderId: 'p1',
      );
      var ns = rules.applyMove(s,
          BridgePlayCardMove(playerId: 'p1', card: const PlayingCard(Suit.hearts, Rank.ace))).newState;
      expect(ns.currentPlayerId, 'p2'); // dummy
      // p2 (dummy) itself can also play — but declarer is the authorised path.
      expect(
        rules.validateMove(ns,
            BridgePlayCardMove(playerId: 'p4', card: const PlayingCard(Suit.hearts, Rank.two))),
        isNull,
      );
      // Non-declarer non-seat player rejected
      expect(
        rules.validateMove(ns,
            BridgePlayCardMove(playerId: 'p3', card: const PlayingCard(Suit.hearts, Rank.two))),
        'NOT_YOUR_TURN',
      );
    });
  });

  // ── Multi-deal session ──────────────────────────────────────────────────

  group('Multi-deal session', () {
    test('newDeal advances dealer and increments deal number', () {
      // Pass out deal 1, advance.
      var s = initialState();
      for (final pid in playerIds) {
        s = rules.applyMove(s, BridgePassMove(playerId: pid)).newState;
      }
      expect(s.phase, GamePhase.roundEnd);
      expect(s.dealNumber, 1);
      expect(s.dealHistory.length, 1);

      s = rules.applyNewDeal(s);
      expect(s.phase, GamePhase.bidding);
      expect(s.dealNumber, 2);
      expect(s.dealerIndex, 1);
      expect(s.vulnerability, Vulnerability.ns);
      expect(s.currentPlayerId, 'p2');
    });

    test('game ends after totalDeals; winners determined by NS vs EW totals', () {
      // Pass out all 4 deals; both teams should tie at 0 → all players are "winners".
      var s = initialState();
      for (var d = 0; d < BridgeConfig.totalDeals; d++) {
        for (var i = 0; i < 4; i++) {
          s = rules
              .applyMove(s, BridgePassMove(playerId: s.currentPlayerId!))
              .newState;
        }
        if (d < BridgeConfig.totalDeals - 1) {
          s = rules.applyNewDeal(s);
        }
      }
      expect(s.phase, GamePhase.gameEnd);
      expect(s.dealHistory.length, BridgeConfig.totalDeals);
      expect(rules.isGameOver(s), true);
      expect(rules.getWinners(s).toSet(), playerIds.toSet());
    });
  });

  // ── Round-end overlay phase ─────────────────────────────────────────────

  group('newDeal move authorisation', () {
    test('only legal during roundEnd or gameEnd', () {
      final s = initialState();
      expect(
        rules.validateMove(s, const BridgeNewDealMove(playerId: 'p1')),
        'NOT_ROUND_END',
      );
    });

    test('any player may dispatch newDeal at roundEnd', () {
      var s = initialState();
      for (final pid in playerIds) {
        s = rules.applyMove(s, BridgePassMove(playerId: pid)).newState;
      }
      expect(
        rules.validateMove(s, const BridgeNewDealMove(playerId: 'p3')),
        isNull,
      );
    });
  });

  // ── Serialization ───────────────────────────────────────────────────────

  group('Serialization', () {
    test('round-trip through JSON preserves state', () {
      var s = initialState();
      s = rules.applyMove(s,
          const BridgeBidMove(playerId: 'p1', level: 2, denomination: BridgeDenomination.hearts)).newState;
      s = rules.applyMove(s, const BridgePassMove(playerId: 'p2')).newState;

      final json = s.toJson();
      final restored = BridgeState.fromJson(json);
      expect(restored.phase, s.phase);
      expect(restored.currentPlayerId, s.currentPlayerId);
      expect(restored.auctionHistory.length, s.auctionHistory.length);
      expect(restored.auctionHistory.first.type, 'bid');
      expect(restored.auctionHistory.first.denomination, BridgeDenomination.hearts);
      expect(restored.hands['p1']!.size, 13);
      expect(restored.vulnerability, Vulnerability.none);
    });
  });

  // ── Player count guard ──────────────────────────────────────────────────

  group('Player count constraints', () {
    test('only 4 is valid', () {
      expect(rules.minPlayers, 4);
      expect(rules.maxPlayers, 4);
      expect(rules.validPlayerCounts, [4]);
    });
  });
}
