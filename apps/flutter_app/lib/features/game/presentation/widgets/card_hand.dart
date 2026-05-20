import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../../../../core/di/skin_theme_providers.dart';
import '../../../../shared/animations/cards/card_fan_animation.dart';
import '../../../../shared/widgets/playing_card_widget.dart';
import '../../providers/game_session_providers.dart';

/// Maps a [Rank] enum to its display string for [PlayingCardWidget].
String rankToDisplay(Rank rank) {
  switch (rank) {
    case Rank.ace:
      return 'A';
    case Rank.king:
      return 'K';
    case Rank.queen:
      return 'Q';
    case Rank.jack:
      return 'J';
    case Rank.ten:
      return '10';
    case Rank.nine:
      return '9';
    case Rank.eight:
      return '8';
    case Rank.seven:
      return '7';
    case Rank.six:
      return '6';
    case Rank.five:
      return '5';
    case Rank.four:
      return '4';
    case Rank.three:
      return '3';
    case Rank.two:
      return '2';
  }
}

/// Maps a [Suit] to the string expected by [PlayingCardWidget].
String suitToString(Suit suit) => suit.name;

/// Sort cards for display: grouped by suit, high rank first.
/// Alternates red/black suits to avoid two adjacent red (or black) suits,
/// which makes the fan easier to scan at a glance.
List<PlayingCard> sortCardsForDisplay(List<PlayingCard> cards) {
  const suitOrder = [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds];
  final sorted = List<PlayingCard>.from(cards);
  sorted.sort((a, b) {
    final suitCmp = suitOrder.indexOf(a.suit).compareTo(
          suitOrder.indexOf(b.suit),
        );
    if (suitCmp != 0) return suitCmp;
    return b.rank.index.compareTo(a.rank.index);
  });
  return sorted;
}

/// Player's hand area using [CardFanAnimation] with [PlayingCardWidget].
class CardHand extends ConsumerWidget {
  final List<PlayingCard> cards;
  final bool isPlayable;
  final Set<PlayingCard>? validCards;
  final void Function(PlayingCard card)? onCardTap;

  /// If true (default), cards are displayed grouped by suit with the highest
  /// rank first within each suit. Games that need custom ordering (e.g., Rummy
  /// melds) can pass false to preserve the incoming order.
  final bool sorted;

  const CardHand({
    super.key,
    required this.cards,
    this.isPlayable = true,
    this.validCards,
    this.onCardTap,
    this.sorted = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayCards = sorted ? sortCardsForDisplay(cards) : cards;
    final selectedCard = ref.watch(selectedCardProvider);
    final selectedIndex =
        selectedCard != null ? displayCards.indexOf(selectedCard) : -1;
    final cardTheme = ref.watch(cardSkinThemeProvider);

    return Container(
      key: const Key('player-hand'),
      child: CardFanAnimation(
        cardCount: displayCards.length,
        selectedIndex: selectedIndex >= 0 ? selectedIndex : null,
        onCardTap: isPlayable
            ? (index) {
                if (index < displayCards.length) {
                  final card = displayCards[index];
                  final canPlay = validCards == null || validCards!.contains(card);
                  if (!canPlay) return;

                  if (selectedCard == card) {
                    // Second tap plays the card
                    onCardTap?.call(card);
                    ref.read(selectedCardProvider.notifier).state = null;
                  } else {
                    // First tap selects the card
                    ref.read(selectedCardProvider.notifier).state = card;
                  }
                }
              }
            : null,
        cardBuilder: (index) {
          if (index >= displayCards.length) return const SizedBox.shrink();
          final card = displayCards[index];
          final canPlay = validCards == null || validCards!.contains(card);

          return PlayingCardWidget(
            suit: suitToString(card.suit),
            rank: rankToDisplay(card.rank),
            isSelected: selectedCard == card,
            isPlayable: isPlayable && canPlay,
            theme: cardTheme,
          );
        },
      ),
    );
  }
}
