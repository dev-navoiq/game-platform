import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

void main() {
  group('PlayingCard', () {
    test('two cards with same suit and rank are equal', () {
      final a = PlayingCard(Suit.hearts, Rank.ace);
      final b = PlayingCard(Suit.hearts, Rank.ace);
      expect(a, equals(b));
    });

    test('cards with different suit are not equal', () {
      final a = PlayingCard(Suit.hearts, Rank.ace);
      final b = PlayingCard(Suit.spades, Rank.ace);
      expect(a, isNot(equals(b)));
    });

    test('cards with different rank are not equal', () {
      final a = PlayingCard(Suit.hearts, Rank.ace);
      final b = PlayingCard(Suit.hearts, Rank.king);
      expect(a, isNot(equals(b)));
    });

    test('toString returns human-readable label', () {
      final card = PlayingCard(Suit.hearts, Rank.ace);
      expect(card.toString(), contains('Hearts'));
      expect(card.toString(), contains('Ace'));
    });

    test('all four suits are distinct', () {
      expect(Suit.values.toSet().length, 4);
    });

    test('each rank has a unique index', () {
      final indices = Rank.values.map((r) => r.index).toSet();
      expect(indices.length, Rank.values.length);
    });
  });
}
