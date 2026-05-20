import '../models/currency.dart';
import '../models/skin.dart';

/// Abstract interface for skin persistence.
abstract class SkinRepository {
  Future<List<Skin>> getAvailableSkins({SkinType? type});
  Future<List<UserSkin>> getUserSkins(String userId);
  Future<Skin> getSkinById(String skinId);
  Future<UserSkin> addUserSkin(String userId, String skinId);
  Future<void> equipSkin(String userId, String skinId);
  Future<void> unequipAllOfType(String userId, SkinType type);
  Future<CurrencyBalance> getBalance(String userId);
  Future<CurrencyBalance> deductCurrency(
    String userId,
    CurrencyType type,
    int amount,
  );
}

/// Service for browsing, purchasing, and equipping cosmetic skins.
class SkinService {
  final SkinRepository _repository;

  SkinService(this._repository);

  /// Get all available skins, optionally filtered by [type].
  Future<List<Skin>> getAvailableSkins({SkinType? type}) =>
      _repository.getAvailableSkins(type: type);

  /// Get all skins owned by the user.
  Future<List<UserSkin>> getUserSkins(String userId) =>
      _repository.getUserSkins(userId);

  /// Purchase a skin. Validates the user has sufficient balance.
  ///
  /// Prefers gem payment if the skin has a gem price; otherwise uses coins.
  /// Throws [StateError] if the user already owns the skin.
  /// Throws [StateError] if the user has insufficient funds.
  Future<UserSkin> purchaseSkin(String userId, String skinId) async {
    // Check if already owned
    final owned = await _repository.getUserSkins(userId);
    if (owned.any((us) => us.skinId == skinId)) {
      throw StateError('User already owns skin $skinId');
    }

    final skin = await _repository.getSkinById(skinId);

    if (skin.isFree) {
      return _repository.addUserSkin(userId, skinId);
    }

    final balance = await _repository.getBalance(userId);

    // Try gems first, then coins
    if (skin.priceGems > 0) {
      if (balance.gems < skin.priceGems) {
        throw StateError(
          'Insufficient gems: need ${skin.priceGems}, have ${balance.gems}',
        );
      }
      await _repository.deductCurrency(
        userId,
        CurrencyType.gems,
        skin.priceGems,
      );
    } else if (skin.priceCoins > 0) {
      if (balance.coins < skin.priceCoins) {
        throw StateError(
          'Insufficient coins: need ${skin.priceCoins}, have ${balance.coins}',
        );
      }
      await _repository.deductCurrency(
        userId,
        CurrencyType.coins,
        skin.priceCoins,
      );
    }

    return _repository.addUserSkin(userId, skinId);
  }

  /// Equip a skin. Un-equips any other skin of the same type.
  ///
  /// Throws [StateError] if the user does not own the skin.
  Future<void> equipSkin(String userId, String skinId) async {
    final owned = await _repository.getUserSkins(userId);
    if (!owned.any((us) => us.skinId == skinId)) {
      throw StateError('User does not own skin $skinId');
    }

    // Look up type to unequip others of same type
    final skin = await _repository.getSkinById(skinId);
    await _repository.unequipAllOfType(userId, skin.type);
    await _repository.equipSkin(userId, skinId);
  }
}
