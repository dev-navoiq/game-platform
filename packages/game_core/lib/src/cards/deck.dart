import 'dart:math';

import 'playing_card.dart';

class Deck {
  final List<PlayingCard> _cards;
  final Random _random;

  Deck._({required List<PlayingCard> cards, Random? random})
      : _cards = cards,
        _random = random ?? Random();

  /// Standard 52-card deck (all suits × all ranks).
  factory Deck.standard52({Random? random}) {
    final cards = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        cards.add(PlayingCard(suit, rank));
      }
    }
    return Deck._(cards: cards, random: random);
  }

  /// 32-card deck: seven and above only (used in games like Twenty-Nine).
  factory Deck.standard32({Random? random}) {
    const validRanks = [
      Rank.seven,
      Rank.eight,
      Rank.nine,
      Rank.ten,
      Rank.jack,
      Rank.queen,
      Rank.king,
      Rank.ace,
    ];
    final cards = <PlayingCard>[];
    for (final suit in Suit.values) {
      for (final rank in validRanks) {
        cards.add(PlayingCard(suit, rank));
      }
    }
    return Deck._(cards: cards, random: random);
  }

  /// Number of cards remaining in the deck.
  int get remaining => _cards.length;

  /// Shuffle the deck in place.
  void shuffle() => _cards.shuffle(_random);

  /// Draw one card from the top. Returns null if the deck is empty.
  PlayingCard? draw() {
    if (_cards.isEmpty) return null;
    return _cards.removeLast();
  }

  /// Draw [count] cards. Returns fewer cards if the deck runs out.
  List<PlayingCard> drawMultiple(int count) {
    final result = <PlayingCard>[];
    for (var i = 0; i < count && _cards.isNotEmpty; i++) {
      result.add(_cards.removeLast());
    }
    return result;
  }

  /// View all remaining cards without removing them.
  List<PlayingCard> get cards => List.unmodifiable(_cards);
}
