import 'package:monetization/monetization.dart';

/// Supabase-backed implementation of [ChallengeRepository].
///
/// Currently a stub — real Supabase queries will be wired in a later session.
class SupabaseChallengeRepository implements ChallengeRepository {
  @override
  Future<List<UserChallenge>> getActiveChallenges(String userId) {
    throw UnimplementedError(
      'SupabaseChallengeRepository.getActiveChallenges',
    );
  }

  @override
  Future<UserChallenge> updateProgress(
    String userId,
    String challengeId,
    int incrementBy,
  ) {
    throw UnimplementedError('SupabaseChallengeRepository.updateProgress');
  }

  @override
  Future<CurrencyBalance> claimReward(String userId, String challengeId) {
    throw UnimplementedError('SupabaseChallengeRepository.claimReward');
  }

  @override
  Future<UserChallenge> rerollChallenge(String userId, String challengeId) {
    throw UnimplementedError('SupabaseChallengeRepository.rerollChallenge');
  }

  @override
  Future<CurrencyBalance> getBalance(String userId) {
    throw UnimplementedError('SupabaseChallengeRepository.getBalance');
  }

  @override
  Future<CurrencyBalance> deductCoins(String userId, int amount) {
    throw UnimplementedError('SupabaseChallengeRepository.deductCoins');
  }
}
