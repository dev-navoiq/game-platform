import 'package:flutter/material.dart';

import '../../core/assets/card_skin_theme.dart';
import '../../core/theme/colors.dart';

class PlayingCardWidget extends StatelessWidget {
  final String suit;
  final String rank;
  final bool isFaceDown;
  final bool isSelected;
  final bool isPlayable;
  final VoidCallback? onTap;
  final String? skinId;
  final CardSkinTheme? theme;

  const PlayingCardWidget({
    super.key,
    required this.suit,
    required this.rank,
    this.isFaceDown = false,
    this.isSelected = false,
    this.isPlayable = true,
    this.onTap,
    this.skinId,
    this.theme,
  });

  CardSkinTheme get _theme => theme ?? CardSkinTheme.classic;

  Color get _suitColor {
    switch (suit) {
      case 'hearts':
      case 'diamonds':
        return _theme.redSuitColor;
      default:
        return _theme.blackSuitColor;
    }
  }

  String get _suitSymbol {
    switch (suit) {
      case 'hearts':
        return '\u2665';
      case 'diamonds':
        return '\u2666';
      case 'clubs':
        return '\u2663';
      case 'spades':
        return '\u2660';
      default:
        return '';
    }
  }

  String get _fullRankName {
    switch (rank) {
      case 'A':
        return 'Ace';
      case 'K':
        return 'King';
      case 'Q':
        return 'Queen';
      case 'J':
        return 'Jack';
      default:
        return rank;
    }
  }

  String get _fullSuitName {
    switch (suit) {
      case 'hearts':
        return 'Hearts';
      case 'diamonds':
        return 'Diamonds';
      case 'clubs':
        return 'Clubs';
      case 'spades':
        return 'Spades';
      default:
        return suit;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cards always render at full opacity — dimming during non-interactive
    // moments (bidding, waiting for other player) made the hand look "blurry".
    // Invalid plays are signalled by the parent shake animation instead.
    final card = Semantics(
      label: '$_fullRankName of $_fullSuitName',
      child: Opacity(
        opacity: 1.0,
        child: GestureDetector(
          onTap: isPlayable ? onTap : null,
          child: Container(
            width: 62,
            height: 90,
            decoration: BoxDecoration(
              color: _theme.cardFaceColor,
              borderRadius: BorderRadius.circular(9),
              border: isSelected
                  ? Border.all(color: AppColors.accent, width: 2.5)
                  : Border.all(color: _theme.cardBorderColor),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: isFaceDown ? _buildBack() : _buildFace(),
          ),
        ),
      ),
    );

    if (isSelected) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              key: const Key('card-selected-indicator'),
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }

  Widget _buildFace() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rank + suit on same line, larger and bolder
          Row(
            children: [
              Text(
                rank,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _suitColor,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 1),
              Text(
                _suitSymbol,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _suitColor,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Large center suit symbol
          Center(
            child: Text(
              _suitSymbol,
              style: TextStyle(
                fontSize: 30,
                color: _suitColor.withOpacity(0.85),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: _theme.cardBackGradient,
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24),
          ),
        ),
      ),
    );
  }
}
