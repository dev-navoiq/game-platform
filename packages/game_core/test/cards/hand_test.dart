import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

/// Additional edge-case tests for Hand beyond those in deck_test.dart.
void main() {
  group('Hand — edge cases', () {
    test('empty hand has size 0', () {
      final hand = Hand([]);
      expect(hand.size, 0);
    });

    test('hasSuit on empty hand returns false', () {
      final hand = Hand([]);
      expect(hand.hasSuit(Suit.hearts), isFalse);
    });

    test('cardsOfSuit on empty hand returns empty list', () {
      final hand = Hand([]);
      expect(hand.cardsOfSuit(Suit.clubs), isEmpty);
    });

    test('adding duplicate card is tracked correctly', () {
      // Hands can have duplicates in some game variants
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.hearts, Rank.ace),
      ]);
      expect(hand.size, 2);
    });

    test('contains returns true for a present card', () {
      final card = PlayingCard(Suit.diamonds, Rank.jack);
      final hand = Hand([card]);
      expect(hand.contains(card), isTrue);
    });

    test('contains returns false for an absent card', () {
      final hand = Hand([PlayingCard(Suit.diamonds, Rank.jack)]);
      expect(hand.contains(PlayingCard(Suit.clubs, Rank.jack)), isFalse);
    });

    test('cards getter returns all cards', () {
      final cards = [
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.spades, Rank.king),
      ];
      final hand = Hand(cards);
      expect(hand.cards.length, 2);
    });
  });
}
