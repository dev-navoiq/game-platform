/// Integration test: plays a complete round of Twenty-Nine driven by a
/// deterministic scripted sequence.  Validates that the rules engine + state
/// machine reach the correct terminal states without manual UI interaction.
///
/// This test is intentionally marked skip until game_twenty_nine is
/// implemented (Session 4).

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

void main() {
  group('Full Game Flow — scripted round', () {
    const playerIds = ['p1', 'p2', 'p3', 'p4'];

    late TwentyNineRules rules;
    late TwentyNineState state;

    setUp(() {
      rules = TwentyNineRules();
      state = rules.createInitialState(playerIds: playerIds, dealerIndex: 0);
    });

    test('game starts in bidding phase with 4 cards each, 16 pending', () {
      expect(state.phase, GamePhase.bidding);
      for (final id in playerIds) {
        expect(state.hands[id]?.size, 4);
      }
      expect(state.pendingDeck.length, 16);
    });

    test('full bidding round leads to trump selection', () {
      // p2 opens bid at 16, others pass
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 16)).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;

      expect(state.phase, GamePhase.trumpSelection);
      expect(state.bidderId, 'p2');
    });

    test('trump declaration leads to playing phase', () {
      // Get to trump selection
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 16)).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;

      // p2 (bid winner, trump selector) picks a suit they hold
      final hand = state.hands['p2']!;
      final suit = hand.cards.first.suit;
      state = rules.applyMove(state, DeclareTrumpMove(playerId: 'p2', suit: suit)).newState;

      expect(state.phase, GamePhase.playing);
      expect(state.trumpSuit, suit);
    });

    test('playing 8 tricks leads to round-end scoring', () {
      // ── Fast-forward to playing phase ──────────────────────────────────
      state = rules.applyMove(state, BidMove(playerId: 'p2', bidValue: 16)).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p3')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p4')).newState;
      state = rules.applyMove(state, PassMove(playerId: 'p1')).newState;
      final suit = state.hands['p2']!.cards.first.suit;
      state = rules.applyMove(state, DeclareTrumpMove(playerId: 'p2', suit: suit)).newState;

      // ── Play out all 8 tricks ──────────────────────────────────────────
      for (var trick = 0; trick < 8; trick++) {
        final leader = state.currentPlayerId;
        final order = _playOrder(playerIds, leader);

        for (final pid in order) {
          final hand = state.hands[pid]!;
          // Follow suit if possible, else play any card
          final ledSuit = state.currentTrick.isEmpty
              ? null
              : state.currentTrick.first.suit;
          final card = ledSuit != null && hand.hasSuit(ledSuit)
              ? hand.cardsOfSuit(ledSuit).first
              : hand.cards.first;
          state = rules.applyMove(state, PlayCardMove(playerId: pid, card: card)).newState;
        }
      }

      expect(
        state.phase,
        anyOf(GamePhase.roundEnd, GamePhase.gameEnd),
        reason: 'After 8 tricks the round should end',
      );
    });
  });
}

List<String> _playOrder(List<String> players, String leader) {
  final idx = players.indexOf(leader);
  return [
    ...players.sublist(idx),
    ...players.sublist(0, idx),
  ];
}
