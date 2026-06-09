import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../../../../core/di/skin_theme_providers.dart';
import '../../../../shared/widgets/playing_card_widget.dart';
import 'card_hand.dart';

/// Dummy's revealed hand laid out face-up above the trick zone.
///
/// Cards are tappable only when [tappable] is true (i.e. it's dummy's turn
/// AND the local player is declarer). Cards not in [validCards] render at
/// reduced opacity to communicate must-follow-suit restrictions.
class BridgeDummyHand extends ConsumerWidget {
  final Hand hand;
  final bool tappable;
  final Set<PlayingCard>? validCards;
  final void Function(PlayingCard card)? onCardTap;

  const BridgeDummyHand({
    super.key,
    required this.hand,
    this.tappable = false,
    this.validCards,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = sortCardsForDisplay(hand.cards);
    final cardTheme = ref.watch(cardSkinThemeProvider);

    return SizedBox(
      key: const Key('bridge-dummy-hand'),
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (_, i) {
          final card = cards[i];
          final canPlay =
              tappable && (validCards == null || validCards!.contains(card));
          return Transform.scale(
            scale: 0.65,
            child: PlayingCardWidget(
              suit: suitToString(card.suit),
              rank: rankToDisplay(card.rank),
              isPlayable: canPlay,
              theme: cardTheme,
              onTap: canPlay ? () => onCardTap?.call(card) : null,
            ),
          );
        },
      ),
    );
  }
}
