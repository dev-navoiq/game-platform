import '../models/currency.dart';
import '../models/season.dart';

/// Abstract interface for season-pass persistence.
abstract class SeasonRepository {
  Future<Season?> getCurrentSeason();
  Future<UserSeasonProgress> getProgress(String userId, String seasonId);
  Future<UserSeasonProgress> saveProgress(UserSeasonProgress progress);
  Future<List<SeasonReward>> getRewards(String seasonId);
  Future<SeasonReward> claimReward(String userId, String seasonId, int level);
  Future<CurrencyBalance> getBalance(String userId);
  Future<CurrencyBalance> deductGems(String userId, int amount);
}

/// Service for season-pass XP, levelling, and reward claiming.
class SeasonService {
  final SeasonRepository _repository;

  SeasonService(this._repository);

  /// Gem cost for the premium season pass.
  static const int premiumPassGemCost = 500;

  /// XP required to advance from level [level] to level+1.
  ///
  /// Formula: level * 100 XP.
  static int xpForLevel(int level) => level * 100;

  /// Get the currently active season, if any.
  Future<Season?> getCurrentSeason() => _repository.getCurrentSeason();

  /// Get the user's progress in the current season.
  ///
  /// Throws [StateError] if no season is active.
  Future<UserSeasonProgress> getProgress(String userId) async {
    final season = await _requireActiveSeason();
    return _repository.getProgress(userId, season.id);
  }

  /// Add XP to the user's season progress, handling level-ups.
  ///
  /// Returns the updated progress. Throws [StateError] if no season is active.
  /// Throws [ArgumentError] if [amount] is not positive.
  Future<UserSeasonProgress> addXp(String userId, int amount) async {
    if (amount <= 0) {
      throw ArgumentError('XP amount must be positive, got $amount');
    }
    final season = await _requireActiveSeason();
    var progress = await _repository.getProgress(userId, season.id);

    var remainingXp = amount + progress.currentXp;
    var level = progress.currentLevel;
    var xpNeeded = xpForLevel(level);

    // Level up as many times as XP allows, capped by totalLevels
    while (remainingXp >= xpNeeded && level < season.totalLevels) {
      remainingXp -= xpNeeded;
      level++;
      xpNeeded = xpForLevel(level);
    }

    // Cap XP at the requirement if already at max level
    if (level >= season.totalLevels) {
      remainingXp = remainingXp.clamp(0, xpNeeded);
    }

    progress = progress.copyWith(
      currentLevel: level,
      currentXp: remainingXp,
      xpToNextLevel: xpNeeded,
    );

    return _repository.saveProgress(progress);
  }

  /// Purchase the premium season pass for the current season.
  ///
  /// Costs [premiumPassGemCost] gems.
  /// Throws [StateError] if no season is active or user already has premium.
  /// Throws [StateError] if insufficient gems.
  Future<UserSeasonProgress> buyPremiumPass(String userId) async {
    final season = await _requireActiveSeason();
    final progress = await _repository.getProgress(userId, season.id);

    if (progress.hasPremiumPass) {
      throw StateError('User already has the premium season pass');
    }

    final balance = await _repository.getBalance(userId);
    if (balance.gems < premiumPassGemCost) {
      throw StateError(
        'Insufficient gems: need $premiumPassGemCost, have ${balance.gems}',
      );
    }

    await _repository.deductGems(userId, premiumPassGemCost);

    final updated = progress.copyWith(hasPremiumPass: true);
    return _repository.saveProgress(updated);
  }

  /// Claim a reward at the given [level].
  ///
  /// Throws [StateError] if no season is active or level is not reached.
  Future<SeasonReward> claimReward(String userId, int level) async {
    final season = await _requireActiveSeason();
    final progress = await _repository.getProgress(userId, season.id);

    if (progress.currentLevel < level) {
      throw StateError(
        'User is level ${progress.currentLevel}, cannot claim level $level reward',
      );
    }
    return _repository.claimReward(userId, season.id, level);
  }

  /// Helper to get the active season, throwing if none exists.
  Future<Season> _requireActiveSeason() async {
    final season = await _repository.getCurrentSeason();
    if (season == null) {
      throw StateError('No active season');
    }
    return season;
  }
}
