import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Categories of cosmetic skins.
enum SkinType { cardBack, cardFace, roomTheme, avatar }

/// A purchasable cosmetic item.
@immutable
class Skin extends Equatable {
  final String id;
  final String name;
  final SkinType type;
  final String? previewUrl;
  final int priceCoins;
  final int priceGems;
  final bool isExclusive;

  const Skin({
    required this.id,
    required this.name,
    required this.type,
    this.previewUrl,
    this.priceCoins = 0,
    this.priceGems = 0,
    this.isExclusive = false,
  });

  bool get isFree => priceCoins == 0 && priceGems == 0;

  @override
  List<Object?> get props =>
      [id, name, type, previewUrl, priceCoins, priceGems, isExclusive];
}

/// A skin owned by a user, with equip state.
@immutable
class UserSkin extends Equatable {
  final String userId;
  final String skinId;
  final DateTime? equippedAt;
  final bool isEquipped;

  const UserSkin({
    required this.userId,
    required this.skinId,
    this.equippedAt,
    this.isEquipped = false,
  });

  @override
  List<Object?> get props => [userId, skinId, equippedAt, isEquipped];
}
