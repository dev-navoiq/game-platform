import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

void main() {
  group('Deck', () {
    group('standard52', () {
      test('has 52 cards', () {
        final deck = Deck.standard52();
        expect(deck.remaining, 52);
      });

      test('contains all 4 suits × 13 ranks', () {
        final deck = Deck.standard52();
        final cards = <PlayingCard>[];
        while (deck.remaining > 0) {
          cards.add(deck.draw()!);
        }
        expect(cards.map((c) => c.suit).toSet().length, 4);
        expect(cards.map((c) => c.rank).toSet().length, 13);
      });

      test('all cards are unique', () {
        final deck = Deck.standard52();
        final cards = <PlayingCard>[];
        while (deck.remaining > 0) {
          cards.add(deck.draw()!);
        }
        expect(cards.toSet().length, 52);
      });
    });

    group('standard32', () {
      test('has 32 cards', () {
        final deck = Deck.standard32();
        expect(deck.remaining, 32);
      });

      test('contains no cards below 7', () {
        final deck = Deck.standard32();
        while (deck.remaining > 0) {
          final card = deck.draw()!;
          expect(
            card.rank.index,
            greaterThanOrEqualTo(Rank.seven.index),
            reason: '$card should not be below 7',
          );
        }
      });
    });

    group('shuffle', () {
      test('shuffled deck has same card count', () {
        final deck = Deck.standard52();
        deck.shuffle();
        expect(deck.remaining, 52);
      });

      test('shuffle randomises order (probabilistic)', () {
        final deck1 = Deck.standard52();
        final deck2 = Deck.standard52();
        deck1.shuffle();

        var matchCount = 0;
        for (var i = 0; i < 10; i++) {
          if (deck1.draw() == deck2.draw()) matchCount++;
        }
        // Statistically near-impossible to match all 10 in sequence
        expect(matchCount, lessThan(10));
      });
    });

    group('draw', () {
      test('draw removes one card from deck', () {
        final deck = Deck.standard52();
        final before = deck.remaining;
        final card = deck.draw();
        expect(card, isNotNull);
        expect(deck.remaining, before - 1);
      });

      test('draw from empty deck returns null', () {
        final deck = Deck.standard32();
        while (deck.remaining > 0) {
          deck.draw();
        }
        expect(deck.draw(), isNull);
      });
    });

    group('drawMultiple', () {
      test('draws the requested number of cards', () {
        final deck = Deck.standard52();
        final hand = deck.drawMultiple(8);
        expect(hand.length, 8);
        expect(deck.remaining, 44);
      });

      test('does not return null cards', () {
        final deck = Deck.standard52();
        final hand = deck.drawMultiple(5);
        expect(hand.every((c) => c != null), isTrue);
      });
    });
  });

  group('Hand', () {
    test('hasSuit returns true when suit is present', () {
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.spades, Rank.king),
      ]);
      expect(hand.hasSuit(Suit.hearts), isTrue);
      expect(hand.hasSuit(Suit.diamonds), isFalse);
    });

    test('cardsOfSuit returns only matching cards', () {
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.hearts, Rank.king),
        PlayingCard(Suit.spades, Rank.jack),
      ]);
      final hearts = hand.cardsOfSuit(Suit.hearts);
      expect(hearts.length, 2);
      expect(hearts.every((c) => c.suit == Suit.hearts), isTrue);
    });

    test('remove returns true and shrinks hand', () {
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.spades, Rank.king),
      ]);
      final removed = hand.remove(PlayingCard(Suit.hearts, Rank.ace));
      expect(removed, isTrue);
      expect(hand.size, 1);
      expect(hand.contains(PlayingCard(Suit.hearts, Rank.ace)), isFalse);
    });

    test('remove returns false when card not in hand', () {
      final hand = Hand([PlayingCard(Suit.hearts, Rank.ace)]);
      final removed = hand.remove(PlayingCard(Suit.spades, Rank.king));
      expect(removed, isFalse);
      expect(hand.size, 1);
    });

    test('size reflects actual card count', () {
      final hand = Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.spades, Rank.king),
        PlayingCard(Suit.clubs, Rank.queen),
      ]);
      expect(hand.size, 3);
    });
  });
}
