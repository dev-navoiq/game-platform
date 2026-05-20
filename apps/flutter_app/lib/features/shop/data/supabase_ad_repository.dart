import 'package:monetization/monetization.dart';

/// Supabase-backed implementation of [AdRepository].
///
/// Currently a stub — real Supabase queries will be wired in a later session.
class SupabaseAdRepository implements AdRepository {
  @override
  Future<AdImpression> recordImpression(
    String userId,
    AdType adType,
    AdPlacement placement,
  ) {
    throw UnimplementedError('SupabaseAdRepository.recordImpression');
  }

  @override
  Future<int> getRewardedAdCountToday(String userId) {
    throw UnimplementedError('SupabaseAdRepository.getRewardedAdCountToday');
  }

  @override
  Future<DateTime?> getLastRewardedAdTime(String userId) {
    throw UnimplementedError('SupabaseAdRepository.getLastRewardedAdTime');
  }

  @override
  Future<int> getCloseCountInWindow(String userId, Duration window) {
    throw UnimplementedError('SupabaseAdRepository.getCloseCountInWindow');
  }

  @override
  Future<CurrencyBalance> addRewardedAdCoins(String userId, int amount) {
    throw UnimplementedError('SupabaseAdRepository.addRewardedAdCoins');
  }
}
