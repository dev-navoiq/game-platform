import '../models/challenge.dart';
import '../models/currency.dart';

/// Abstract interface for challenge persistence.
abstract class ChallengeRepository {
  Future<List<UserChallenge>> getActiveChallenges(String userId);
  Future<UserChallenge> updateProgress(
    String userId,
    String challengeId,
    int incrementBy,
  );
  Future<CurrencyBalance> claimReward(String userId, String challengeId);
  Future<UserChallenge> rerollChallenge(String userId, String challengeId);
  Future<CurrencyBalance> getBalance(String userId);
  Future<CurrencyBalance> deductCoins(String userId, int amount);
}

/// Service for daily/weekly challenge logic.
///
/// The platform assigns 3 daily and 5 weekly challenges per user.
class ChallengeService {
  final ChallengeRepository _repository;

  ChallengeService(this._repository);

  /// Number of daily challenges assigned to each user.
  static const int dailyChallengeCount = 3;

  /// Number of weekly challenges assigned to each user.
  static const int weeklyChallengeCount = 5;

  /// Coin cost to reroll a challenge.
  static const int rerollCostCoins = 25;

  /// Get all active challenges for the user.
  Future<List<UserChallenge>> getActiveChallenges(String userId) =>
      _repository.getActiveChallenges(userId);

  /// Increment a challenge's progress by [incrementBy].
  ///
  /// Throws [ArgumentError] if [incrementBy] is not positive.
  Future<UserChallenge> updateProgress(
    String userId,
    String challengeId,
    int incrementBy,
  ) {
    if (incrementBy <= 0) {
      throw ArgumentError(
        'incrementBy must be positive, got $incrementBy',
      );
    }
    return _repository.updateProgress(userId, challengeId, incrementBy);
  }

  /// Reroll a challenge, replacing it with a different one.
  ///
  /// Costs [rerollCostCoins] coins. Throws [StateError] if the user
  /// cannot afford the reroll or the challenge is not rerollable.
  Future<UserChallenge> rerollChallenge(
    String userId,
    String challengeId,
  ) async {
    // Check balance
    final balance = await _repository.getBalance(userId);
    if (balance.coins < rerollCostCoins) {
      throw StateError(
        'Insufficient coins for reroll: need $rerollCostCoins, '
        'have ${balance.coins}',
      );
    }

    // Check that the challenge is rerollable
    final challenges = await _repository.getActiveChallenges(userId);
    final challenge = challenges
        .where((c) => c.challengeId == challengeId)
        .toList();
    if (challenge.isEmpty) {
      throw StateError('Challenge $challengeId not found');
    }
    if (!challenge.first.canReroll) {
      throw StateError('Challenge $challengeId cannot be rerolled');
    }

    // Deduct coins
    await _repository.deductCoins(userId, rerollCostCoins);

    // Perform reroll
    return _repository.rerollChallenge(userId, challengeId);
  }

  /// Claim the reward for a completed challenge. Returns updated balance.
  ///
  /// Throws [StateError] if the challenge is not completed.
  Future<CurrencyBalance> claimReward(
    String userId,
    String challengeId,
  ) async {
    final challenges = await _repository.getActiveChallenges(userId);
    final matches = challenges
        .where((c) => c.challengeId == challengeId)
        .toList();
    if (matches.isEmpty) {
      throw StateError('Challenge $challengeId not found');
    }
    if (!matches.first.isCompleted) {
      throw StateError('Challenge $challengeId is not completed');
    }
    return _repository.claimReward(userId, challengeId);
  }
}
