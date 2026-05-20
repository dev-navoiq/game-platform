import 'playing_card.dart';

/// A player's hand of cards.
class Hand {
  final List<PlayingCard> _cards;

  Hand(List<PlayingCard> cards) : _cards = List.from(cards);

  /// Number of cards in hand.
  int get size => _cards.length;

  /// All cards in hand (unmodifiable view).
  List<PlayingCard> get cards => List.unmodifiable(_cards);

  /// Whether the hand contains any card of [suit].
  bool hasSuit(Suit suit) => _cards.any((c) => c.suit == suit);

  /// All cards in hand matching [suit].
  List<PlayingCard> cardsOfSuit(Suit suit) =>
      _cards.where((c) => c.suit == suit).toList();

  /// Whether [card] is present in the hand.
  bool contains(PlayingCard card) => _cards.contains(card);

  /// Remove [card] from hand. Returns true if removed, false if not found.
  bool remove(PlayingCard card) => _cards.remove(card);

  /// Add a card to the hand.
  void add(PlayingCard card) => _cards.add(card);

  /// Add multiple cards.
  void addAll(List<PlayingCard> cards) => _cards.addAll(cards);

  /// Remove and return card at [index].
  PlayingCard removeAt(int index) => _cards.removeAt(index);

  /// Sort hand by suit then rank (ascending).
  void sort() => _cards.sort((a, b) {
        final suitCmp = a.suit.index.compareTo(b.suit.index);
        if (suitCmp != 0) return suitCmp;
        return a.rank.index.compareTo(b.rank.index);
      });

  /// Sort hand by suit then rank descending — standard display order
  /// (Ace-high first) for trick-taking games.
  void sortForDisplay() => _cards.sort((a, b) {
        final suitCmp = a.suit.index.compareTo(b.suit.index);
        if (suitCmp != 0) return suitCmp;
        return b.rank.index.compareTo(a.rank.index);
      });

  /// Clear hand.
  void clear() => _cards.clear();

  /// Create a shallow copy.
  Hand copy() => Hand(List.from(_cards));

  List<Map<String, dynamic>> toJson() =>
      _cards.map((c) => c.toJson()).toList();

  factory Hand.fromJson(List<dynamic> json) => Hand(
        json
            .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
