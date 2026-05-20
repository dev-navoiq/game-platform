import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import 'card_hand.dart';

/// Central trick area showing played cards in a grid layout.
///
/// Cards are displayed in 1-2 rows with small avatar badges below each.
class TrickZone extends StatelessWidget {
  final List<TrickCard> currentTrick;
  final List<String> playerOrder;
  final Map<String, String> playerEmojis;
  final String? winningPlayerId;
  final Suit? trumpSuit;

  const TrickZone({
    super.key,
    required this.currentTrick,
    required this.playerOrder,
    this.playerEmojis = const {},
    this.winningPlayerId,
    this.trumpSuit,
  });

  static const double _cardW = 56;
  static const double _cardH = 80;
  static const double _gap = 8;
  static const _rotations = [-3.0, 4.0, -2.0, 3.0, -4.0, 2.0, -3.0, 4.0];

  @override
  Widget build(BuildContext context) {
    if (currentTrick.isEmpty) {
      return const SizedBox(width: 240, height: 190);
    }

    final positions = _calculatePositions(currentTrick.length);

    return SizedBox(
      width: 240,
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient shadow under card pile
          Center(
            child: Container(
              width: 180,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(55),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Cards
          ...currentTrick.asMap().entries.map((entry) {
            final i = entry.key;
            final trickCard = entry.value;
            final pos = positions[i];
            final rot = _rotations[i % _rotations.length];
            final isWinning = trickCard.playerId == winningPlayerId;
            final isTrump =
                trumpSuit != null && trickCard.card.suit == trumpSuit;
            final emoji = playerEmojis[trickCard.playerId] ?? '🎮';

            return AnimatedPositioned(
              duration: Duration(milliseconds: 300 + i * 60),
              curve: Curves.easeOut,
              left: pos.dx,
              top: pos.dy,
              child: _TrickCardWithBadge(
                trickCard: trickCard,
                emoji: emoji,
                rotation: rot,
                isWinning: isWinning,
                isTrump: isTrump,
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Offset> _calculatePositions(int n) {
    const zoneW = 240.0;
    const zoneH = 190.0;

    if (n == 0) return [];

    if (n <= 4) {
      final totalW = n * _cardW + (n - 1) * _gap;
      final startX = (zoneW - totalW) / 2;
      final y = (zoneH - _cardH) / 2;
      return List.generate(
          n, (i) => Offset(startX + i * (_cardW + _gap), y));
    }

    // Two rows
    final row1n = (n / 2).ceil();
    final row2n = (n / 2).floor();
    final startY = (zoneH - (2 * _cardH + _gap)) / 2;
    final positions = <Offset>[];

    final r1W = row1n * _cardW + (row1n - 1) * _gap;
    final r1x = (zoneW - r1W) / 2;
    for (var i = 0; i < row1n; i++) {
      positions.add(Offset(r1x + i * (_cardW + _gap), startY));
    }

    final r2W = row2n * _cardW + (row2n - 1) * _gap;
    final r2x = (zoneW - r2W) / 2;
    for (var i = 0; i < row2n; i++) {
      positions.add(Offset(r2x + i * (_cardW + _gap), startY + _cardH + _gap));
    }

    return positions;
  }
}

class _TrickCardWithBadge extends StatelessWidget {
  final TrickCard trickCard;
  final String emoji;
  final double rotation;
  final bool isWinning;
  final bool isTrump;

  const _TrickCardWithBadge({
    required this.trickCard,
    required this.emoji,
    required this.rotation,
    required this.isWinning,
    required this.isTrump,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * 3.14159 / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card
          Container(
            width: 56,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isWinning
                    ? AppColors.accent
                    : isTrump
                        ? AppColors.accent.withOpacity(0.55)
                        : Colors.grey.shade300,
                width: isWinning ? 2.5 : 1,
              ),
              boxShadow: [
                if (isWinning)
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.32),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rankToDisplay(trickCard.card.rank),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _cardColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    _suitSymbol,
                    style: TextStyle(fontSize: 12, color: _cardColor, height: 1),
                  ),
                  const Spacer(),
                  Center(
                    child: Text(
                      _suitSymbol,
                      style: TextStyle(
                        fontSize: 20,
                        color: _cardColor.withOpacity(0.07),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // Avatar badge
          Positioned(
            top: -9,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.avatarBg1, AppColors.avatarBg2],
                  ),
                  border: Border.all(
                    color: isWinning ? AppColors.accent : Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    if (isWinning)
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _cardColor {
    final suit = trickCard.card.suit;
    return (suit == Suit.hearts || suit == Suit.diamonds)
        ? AppColors.cardRed
        : AppColors.cardBlack;
  }

  String get _suitSymbol {
    switch (trickCard.card.suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }
}
