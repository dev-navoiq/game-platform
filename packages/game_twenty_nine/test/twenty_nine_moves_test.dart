import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

void main() {
  group('Move Types', () {
    group('BidMove', () {
      test('equality works', () {
        final a = BidMove(playerId: 'p1', bidValue: 16);
        final b = BidMove(playerId: 'p1', bidValue: 16);
        expect(a, equals(b));
      });

      test('different bid values are not equal', () {
        final a = BidMove(playerId: 'p1', bidValue: 16);
        final b = BidMove(playerId: 'p1', bidValue: 17);
        expect(a, isNot(equals(b)));
      });
    });

    group('PassMove', () {
      test('equality works', () {
        final a = PassMove(playerId: 'p2');
        final b = PassMove(playerId: 'p2');
        expect(a, equals(b));
      });
    });

    group('DeclareTrumpMove', () {
      test('stores suit correctly', () {
        final move = DeclareTrumpMove(playerId: 'p3', suit: Suit.hearts);
        expect(move.suit, Suit.hearts);
        expect(move.playerId, 'p3');
      });
    });

    group('PlayCardMove', () {
      test('stores card correctly', () {
        final card = PlayingCard(Suit.spades, Rank.jack);
        final move = PlayCardMove(playerId: 'p1', card: card);
        expect(move.card, card);
      });

      test('equality works', () {
        final card = PlayingCard(Suit.spades, Rank.jack);
        final a = PlayCardMove(playerId: 'p1', card: card);
        final b = PlayCardMove(playerId: 'p1', card: card);
        expect(a, equals(b));
      });
    });

    group('RevealTrumpMove', () {
      test('can be created', () {
        final move = RevealTrumpMove(playerId: 'p2');
        expect(move.playerId, 'p2');
      });
    });
  });

  group('MoveResult', () {
    test('valid result has isValid = true', () {
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
        playerOrder: ['p1', 'p2', 'p3', 'p4'],
      );
      final result = MoveResult.valid(newState: state);
      expect(result.isValid, isTrue);
      expect(result.error, isNull);
    });

    test('invalid result has isValid = false and carries error', () {
      final result = MoveResult.invalid(error: 'NOT_YOUR_TURN');
      expect(result.isValid, isFalse);
      expect(result.error, 'NOT_YOUR_TURN');
    });
  });
}
