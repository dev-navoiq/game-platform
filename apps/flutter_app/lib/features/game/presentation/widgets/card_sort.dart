import 'package:game_core/game_core.dart';

/// A sort function that returns a new list ordered for display.
typedef CardSorter = List<PlayingCard> Function(List<PlayingCard> cards);

/// Default sort: alternating-colour suit order (♠♥♣♦), highest rank first
/// within each suit. Reused by any game that doesn't have a specific
/// convention.
List<PlayingCard> defaultCardSort(List<PlayingCard> cards) {
  const suitOrder = [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds];
  final sorted = List<PlayingCard>.from(cards);
  sorted.sort((a, b) {
    final suitCmp = suitOrder
        .indexOf(a.suit)
        .compareTo(suitOrder.indexOf(b.suit));
    if (suitCmp != 0) return suitCmp;
    return b.rank.index.compareTo(a.rank.index);
  });
  return sorted;
}

/// Bridge convention: alternating-colour suit groups (♠♥♣♦), Ace high.
/// Same as default, but pinned explicitly so a future tweak to default
/// doesn't shift Bridge hands.
const CardSorter bridgeCardSort = defaultCardSort;

/// Twenty-Nine: within each suit, order by 29's trick-taking strength
/// (J > 9 > A > 10 > K > Q > 8 > 7) so the high-power cards always
/// appear at the same end of each suit run regardless of standard rank.
List<PlayingCard> twentyNineCardSort(List<PlayingCard> cards) {
  const suitOrder = [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds];
  // Higher number = stronger card in 29.
  const strength = <Rank, int>{
    Rank.jack: 8,
    Rank.nine: 7,
    Rank.ace: 6,
    Rank.ten: 5,
    Rank.king: 4,
    Rank.queen: 3,
    Rank.eight: 2,
    Rank.seven: 1,
  };
  final sorted = List<PlayingCard>.from(cards);
  sorted.sort((a, b) {
    final suitCmp = suitOrder
        .indexOf(a.suit)
        .compareTo(suitOrder.indexOf(b.suit));
    if (suitCmp != 0) return suitCmp;
    final sa = strength[a.rank] ?? a.rank.index;
    final sb = strength[b.rank] ?? b.rank.index;
    return sb.compareTo(sa);
  });
  return sorted;
}
