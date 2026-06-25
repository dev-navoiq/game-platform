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

    test('each player starts with 4 cards (first deal); 16 wait in pendingDeck', () {
      for (final id in playerIds) {
        expect(initialState.hands[id]?.size, 4);
      }
      expect(initialState.pendingDeck.length, 16);
    });

    test('declareTrump deals the second 4 cards into each hand', () {
      var state = initialState;
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 16)).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;
      final suit = state.hands['p2']!.cards.first.suit;
      state = rules.applyMove(state, DeclareTrumpMove(playerId: 'p2', suit: suit)).newState;
      for (final id in playerIds) {
        expect(state.hands[id]?.size, 8);
      }
      expect(state.pendingDeck, isEmpty);
      expect(state.phase, GamePhase.playing);
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
    test('game ends when a team\'s red scorecard fills (6 pips)', () {
      final state = TwentyNineState(
        phase: GamePhase.gameEnd,
        sessionScores: {0: 6, 1: 4},
        redPips: {0: 6, 1: 4},
        blackPips: {0: 4, 1: 6},
        hands: {},
        dealerIndex: 0,
        playerOrder: playerIds,
      );
      expect(rules.isGameOver(state), isTrue);
    });

    test('winners are the team with the full red scorecard', () {
      final state = TwentyNineState(
        phase: GamePhase.gameEnd,
        sessionScores: {0: 6, 1: 4},
        redPips: {0: 6, 1: 4},
        blackPips: {0: 4, 1: 6},
        hands: {},
        dealerIndex: 0,
        playerOrder: playerIds,
      );
      // Team 0 = p1 + p3
      expect(rules.getWinners(state), containsAll(['p1', 'p3']));
    });
  });

  // ── Royal Wedding (K + Q of trump) ────────────────────────────────────────

  group('Royal Wedding', () {
    /// Build a "between tricks" state where the claimant leads the next
    /// trick with K+Q of [trump] in hand and one trick already won by their
    /// team.
    TwentyNineState royalWeddingFixture({
      required Suit trump,
      required int currentBid,
      required String claimant,
      required int claimantTeamTricksWon,
    }) {
      final claimantTeam = playerIds.indexOf(claimant) % 2;
      final otherTeam = (claimantTeam + 1) % 2;
      return TwentyNineState(
        phase: GamePhase.playing,
        currentPlayerId: claimant,
        hands: {
          for (final id in playerIds)
            id: id == claimant
                ? Hand([
                    PlayingCard(trump, Rank.king),
                    PlayingCard(trump, Rank.queen),
                    PlayingCard(Suit.diamonds, Rank.ten),
                  ])
                : Hand([PlayingCard(Suit.clubs, Rank.eight)]),
        },
        currentTrick: const [],
        trumpSuit: trump,
        trumpRevealed: true,
        currentBid: currentBid,
        bidderId: 'p2',
        trumpSelector: 'p2',
        dealerIndex: 0,
        playerOrder: playerIds,
        tricksWon: {
          claimantTeam: claimantTeamTricksWon,
          otherTeam: 0,
        },
      );
    }

    test('bidder-team claim with bid ≥ 20 reduces threshold by 4', () {
      // p2 (team 1) bid 20, but we set p1 as claimant here for simplicity —
      // p1 is on team 0 (defenders), so this is the defender path.
      // Use a bidder-team claimant by making p2 the bidder + claimant.
      final state = royalWeddingFixture(
        trump: Suit.spades,
        currentBid: 20,
        claimant: 'p2',
        claimantTeamTricksWon: 1,
      );
      // Validate move passes.
      final move = ClaimRoyalWeddingMove(playerId: 'p2');
      expect(rules.validateMove(state, move), isNull);
      // Apply: bidAdjustment should drop by 4 (negative).
      final next = rules.applyMove(state, move).newState;
      expect(next.bidAdjustment, -4);
      expect(next.royalWeddingClaimedByTeam, contains(1));
    });

    test('bidder-team claim with bid < 20 is rejected', () {
      final state = royalWeddingFixture(
        trump: Suit.spades,
        currentBid: 18,
        claimant: 'p2',
        claimantTeamTricksWon: 1,
      );
      final move = ClaimRoyalWeddingMove(playerId: 'p2');
      expect(rules.validateMove(state, move), 'BID_BELOW_HIGH_THRESHOLD');
    });

    test('defender claim raises threshold by 4', () {
      // p1 on team 0; bidder p2 on team 1.
      final state = royalWeddingFixture(
        trump: Suit.spades,
        currentBid: 16,
        claimant: 'p1',
        claimantTeamTricksWon: 1,
      );
      final move = ClaimRoyalWeddingMove(playerId: 'p1');
      expect(rules.validateMove(state, move), isNull);
      final next = rules.applyMove(state, move).newState;
      expect(next.bidAdjustment, 4);
      expect(next.royalWeddingClaimedByTeam, contains(0));
    });

    test('claim rejected when team has won zero tricks', () {
      final state = royalWeddingFixture(
        trump: Suit.spades,
        currentBid: 22,
        claimant: 'p2',
        claimantTeamTricksWon: 0,
      );
      final move = ClaimRoyalWeddingMove(playerId: 'p2');
      expect(rules.validateMove(state, move), 'NO_TRICK_WON_YET');
    });

    test('claim rejected mid-trick', () {
      final state = royalWeddingFixture(
        trump: Suit.spades,
        currentBid: 22,
        claimant: 'p2',
        claimantTeamTricksWon: 1,
      ).copyWith(
        currentTrick: [
          TrickCard(
            playerId: 'p1',
            card: PlayingCard(Suit.hearts, Rank.eight),
            seatIndex: 0,
          ),
        ],
      );
      final move = ClaimRoyalWeddingMove(playerId: 'p2');
      expect(rules.validateMove(state, move), 'TRICK_IN_PROGRESS');
    });

    test('each team may only claim once per round', () {
      final state = royalWeddingFixture(
        trump: Suit.spades,
        currentBid: 22,
        claimant: 'p2',
        claimantTeamTricksWon: 1,
      ).copyWith(royalWeddingClaimedByTeam: {1});
      final move = ClaimRoyalWeddingMove(playerId: 'p2');
      expect(rules.validateMove(state, move), 'TEAM_ALREADY_CLAIMED');
    });
  });

  // ── Edge Cases ────────────────────────────────────────────────────────────

  group('Edge Cases', () {
    test('all players passing triggers immediate redeal', () {
      var state = initialState;
      final originalDealerIndex = state.dealerIndex;
      final originalRoundNumber = state.roundNumber;
      final originalHands = Map<String, List<PlayingCard>>.fromEntries(
        state.playerOrder.map(
          (pid) => MapEntry(pid, List<PlayingCard>.from(state.hands[pid]!.cards)),
        ),
      );

      final result = rules.applyMove(state, PassMove(playerId: 'p2'));
      state = result.newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      final finalResult = rules.applyMove(state, PassMove(playerId: 'p1'));
      state = finalResult.newState;

      // Bidding restarted with a fresh deal.
      expect(state.phase, GamePhase.bidding);
      expect(state.passCount, 0);
      expect(state.currentBid, 0);
      expect(state.bidderId, isNull);

      // Dealer rotated.
      expect(state.dealerIndex, (originalDealerIndex + 1) % 4);

      // First bidder is dealer+1.
      final expectedFirstBidder =
          state.playerOrder[(state.dealerIndex + 1) % 4];
      expect(state.currentPlayerId, expectedFirstBidder);

      // Round number preserved (not a scored new round).
      expect(state.roundNumber, originalRoundNumber);

      // Each player received 4 fresh cards.
      for (final pid in state.playerOrder) {
        expect(state.hands[pid]?.size, 4);
      }

      // 16 cards held back for second deal.
      expect(state.pendingDeck.length, 16);

      // Hands changed (new deck was dealt).
      var anyHandChanged = false;
      for (final pid in state.playerOrder) {
        final oldCards = originalHands[pid]!.toSet();
        final newCards = state.hands[pid]!.cards.toSet();
        if (oldCards != newCards) anyHandChanged = true;
      }
      expect(anyHandChanged, isTrue);

      // handDissolved event emitted.
      expect(
        finalResult.events.any((e) => e.type == GameEventType.handDissolved),
        isTrue,
      );
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
