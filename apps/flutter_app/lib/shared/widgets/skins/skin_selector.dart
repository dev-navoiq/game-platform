import 'package:flutter/material.dart';

import '../../../core/assets/asset_registry.dart';
import '../../../core/assets/card_skin_theme.dart';
import '../../../core/assets/room_skin_theme.dart';
import '../../../core/theme/colors.dart';
import '../glass_card.dart';
import '../playing_card_widget.dart';

/// Type of skin being selected.
enum SkinSelectorType { card, room }

/// Glass-styled grid for selecting card or room skins.
///
/// Shows live previews: mini cards for card skins, colour swatches for rooms.
class SkinSelector extends StatelessWidget {
  final SkinSelectorType type;
  final String selectedSkinId;
  final Set<String> ownedSkinIds;
  final ValueChanged<String> onSelect;
  final ValueChanged<String>? onBuy;

  const SkinSelector({
    super.key,
    required this.type,
    required this.selectedSkinId,
    required this.ownedSkinIds,
    required this.onSelect,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final registry = AssetRegistry.instance;

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: type == SkinSelectorType.card
          ? registry.allCardSkins.map(_buildCardSkinItem).toList()
          : registry.allRoomSkins.map(_buildRoomSkinItem).toList(),
    );
  }

  Widget _buildCardSkinItem(CardSkinTheme skin) {
    final isSelected = skin.id == selectedSkinId;
    final isOwned = ownedSkinIds.contains(skin.id) || skin.isFree;

    return GestureDetector(
      onTap: () {
        if (isOwned) {
          onSelect(skin.id);
        } else {
          onBuy?.call(skin.id);
        }
      },
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Live card preview
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 42,
                  height: 60,
                  child: PlayingCardWidget(
                    suit: 'hearts',
                    rank: 'A',
                    theme: skin,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 42,
                  height: 60,
                  child: PlayingCardWidget(
                    suit: 'spades',
                    rank: 'K',
                    theme: skin,
                    isFaceDown: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              skin.displayName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusBadge(
              isSelected: isSelected,
              isOwned: isOwned,
              priceCoins: skin.priceCoins,
              priceGems: skin.priceGems,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSkinItem(RoomSkinTheme skin) {
    final isSelected = skin.id == selectedSkinId;
    final isOwned = ownedSkinIds.contains(skin.id) || skin.isFree;

    return GestureDetector(
      onTap: () {
        if (isOwned) {
          onSelect(skin.id);
        } else {
          onBuy?.call(skin.id);
        }
      },
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Colour swatch preview
            Container(
              width: 80,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [skin.feltColor, skin.feltDarkColor],
                ),
                border: isSelected
                    ? Border.all(color: AppColors.accent, width: 2.5)
                    : Border.all(color: Colors.white24),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: skin.accentColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              skin.displayName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusBadge(
              isSelected: isSelected,
              isOwned: isOwned,
              priceCoins: skin.priceCoins,
              priceGems: skin.priceGems,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isSelected,
    required bool isOwned,
    required int priceCoins,
    required int priceGems,
  }) {
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.success.withOpacity(0.15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: AppColors.success),
            const SizedBox(width: 3),
            const Text(
              'Equipped',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    if (isOwned) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.accent.withOpacity(0.1),
        ),
        child: const Text(
          'Equip',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      );
    }

    // Locked — show price
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 3),
        if (priceCoins > 0) ...[
          Icon(Icons.circle, size: 9, color: AppColors.accent),
          const SizedBox(width: 2),
          Text(
            '$priceCoins',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
        if (priceCoins > 0 && priceGems > 0) const SizedBox(width: 4),
        if (priceGems > 0) ...[
          Icon(Icons.diamond, size: 9, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            '$priceGems',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ],
    );
  }
}
