import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

void main() {
  group('TwentyNineState', () {
    final playerIds = ['p1', 'p2', 'p3', 'p4'];

    group('copyWith', () {
      test('unchanged fields stay the same', () {
        final state = TwentyNineState(
          phase: GamePhase.bidding,
          currentPlayerId: 'p1',
          hands: {},
          currentTrick: [],
          trumpSuit: null,
          trumpRevealed: false,
          currentBid: 0,
          bidderId: null,
          trumpSelector: null,
          dealerIndex: 0,
          playerOrder: playerIds,
          sessionScores: {0: 0, 1: 0},
          allPlayersPassed: false,
        );

        final copy = state.copyWith(currentPlayerId: 'p2');
        expect(copy.phase, GamePhase.bidding);
        expect(copy.currentPlayerId, 'p2');
        expect(copy.dealerIndex, 0);
      });

      test('copyWith with no arguments returns equivalent state', () {
        final state = TwentyNineState(
          phase: GamePhase.playing,
          currentPlayerId: 'p3',
          hands: {},
          currentTrick: [],
          trumpSuit: Suit.hearts,
          trumpRevealed: true,
          currentBid: 18,
          bidderId: 'p3',
          trumpSelector: 'p1',
          dealerIndex: 1,
          playerOrder: playerIds,
          sessionScores: {0: 2, 1: 1},
          allPlayersPassed: false,
        );

        final copy = state.copyWith();
        expect(copy.phase, state.phase);
        expect(copy.trumpSuit, state.trumpSuit);
        expect(copy.currentBid, state.currentBid);
      });
    });

    group('partnerships', () {
      test('team 0 is [p1, p3] and team 1 is [p2, p4]', () {
        final state = TwentyNineState(
          phase: GamePhase.bidding,
          currentPlayerId: 'p1',
          hands: {},
          currentTrick: [],
          trumpSuit: null,
          trumpRevealed: false,
          currentBid: 0,
          bidderId: null,
          trumpSelector: null,
          dealerIndex: 0,
          playerOrder: playerIds,
        );

        expect(state.teamForPlayer('p1'), 0);
        expect(state.teamForPlayer('p3'), 0);
        expect(state.teamForPlayer('p2'), 1);
        expect(state.teamForPlayer('p4'), 1);
      });
    });

    group('nextPlayer', () {
      test('returns next player in order', () {
        final state = TwentyNineState(
          phase: GamePhase.bidding,
          currentPlayerId: 'p2',
          hands: {},
          currentTrick: [],
          trumpSuit: null,
          trumpRevealed: false,
          currentBid: 0,
          bidderId: null,
          trumpSelector: null,
          dealerIndex: 0,
          playerOrder: playerIds,
        );

        expect(state.nextPlayerId, 'p3');
      });

      test('wraps around after last player', () {
        final state = TwentyNineState(
          phase: GamePhase.bidding,
          currentPlayerId: 'p4',
          hands: {},
          currentTrick: [],
          trumpSuit: null,
          trumpRevealed: false,
          currentBid: 0,
          bidderId: null,
          trumpSelector: null,
          dealerIndex: 0,
          playerOrder: playerIds,
        );

        expect(state.nextPlayerId, 'p1');
      });
    });
  });
}
