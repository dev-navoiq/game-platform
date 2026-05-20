import 'package:monetization/monetization.dart';

/// Supabase-backed implementation of [SeasonRepository].
///
/// Currently a stub — real Supabase queries will be wired in a later session.
class SupabaseSeasonRepository implements SeasonRepository {
  @override
  Future<Season?> getCurrentSeason() {
    throw UnimplementedError('SupabaseSeasonRepository.getCurrentSeason');
  }

  @override
  Future<UserSeasonProgress> getProgress(String userId, String seasonId) {
    throw UnimplementedError('SupabaseSeasonRepository.getProgress');
  }

  @override
  Future<UserSeasonProgress> saveProgress(UserSeasonProgress progress) {
    throw UnimplementedError('SupabaseSeasonRepository.saveProgress');
  }

  @override
  Future<List<SeasonReward>> getRewards(String seasonId) {
    throw UnimplementedError('SupabaseSeasonRepository.getRewards');
  }

  @override
  Future<SeasonReward> claimReward(
    String userId,
    String seasonId,
    int level,
  ) {
    throw UnimplementedError('SupabaseSeasonRepository.claimReward');
  }

  @override
  Future<CurrencyBalance> getBalance(String userId) {
    throw UnimplementedError('SupabaseSeasonRepository.getBalance');
  }

  @override
  Future<CurrencyBalance> deductGems(String userId, int amount) {
    throw UnimplementedError('SupabaseSeasonRepository.deductGems');
  }
}
