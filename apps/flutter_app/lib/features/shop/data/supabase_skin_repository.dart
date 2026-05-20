import 'package:monetization/monetization.dart';

/// Supabase-backed implementation of [SkinRepository].
///
/// Currently a stub — real Supabase queries will be wired in a later session.
class SupabaseSkinRepository implements SkinRepository {
  @override
  Future<List<Skin>> getAvailableSkins({SkinType? type}) {
    throw UnimplementedError('SupabaseSkinRepository.getAvailableSkins');
  }

  @override
  Future<List<UserSkin>> getUserSkins(String userId) {
    throw UnimplementedError('SupabaseSkinRepository.getUserSkins');
  }

  @override
  Future<Skin> getSkinById(String skinId) {
    throw UnimplementedError('SupabaseSkinRepository.getSkinById');
  }

  @override
  Future<UserSkin> addUserSkin(String userId, String skinId) {
    throw UnimplementedError('SupabaseSkinRepository.addUserSkin');
  }

  @override
  Future<void> equipSkin(String userId, String skinId) {
    throw UnimplementedError('SupabaseSkinRepository.equipSkin');
  }

  @override
  Future<void> unequipAllOfType(String userId, SkinType type) {
    throw UnimplementedError('SupabaseSkinRepository.unequipAllOfType');
  }

  @override
  Future<CurrencyBalance> getBalance(String userId) {
    throw UnimplementedError('SupabaseSkinRepository.getBalance');
  }

  @override
  Future<CurrencyBalance> deductCurrency(
    String userId,
    CurrencyType type,
    int amount,
  ) {
    throw UnimplementedError('SupabaseSkinRepository.deductCurrency');
  }
}
