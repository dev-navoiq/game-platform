import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A time-limited season with leveled rewards.
@immutable
class Season extends Equatable {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int totalLevels;

  const Season({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.totalLevels = 50,
  });

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays.clamp(0, 999);
  }

  @override
  List<Object?> get props => [id, name, startDate, endDate, totalLevels];
}

/// Tracks a user's progress through a season.
@immutable
class UserSeasonProgress extends Equatable {
  final String userId;
  final String seasonId;
  final int currentLevel;
  final int currentXp;
  final int xpToNextLevel;
  final bool hasPremiumPass;

  const UserSeasonProgress({
    required this.userId,
    required this.seasonId,
    this.currentLevel = 1,
    this.currentXp = 0,
    this.xpToNextLevel = 100,
    this.hasPremiumPass = false,
  });

  /// Progress toward next level as a fraction from 0.0 to 1.0.
  double get levelProgress =>
      xpToNextLevel > 0 ? (currentXp / xpToNextLevel).clamp(0.0, 1.0) : 0;

  UserSeasonProgress copyWith({
    String? userId,
    String? seasonId,
    int? currentLevel,
    int? currentXp,
    int? xpToNextLevel,
    bool? hasPremiumPass,
  }) =>
      UserSeasonProgress(
        userId: userId ?? this.userId,
        seasonId: seasonId ?? this.seasonId,
        currentLevel: currentLevel ?? this.currentLevel,
        currentXp: currentXp ?? this.currentXp,
        xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
        hasPremiumPass: hasPremiumPass ?? this.hasPremiumPass,
      );

  @override
  List<Object?> get props =>
      [userId, seasonId, currentLevel, currentXp, xpToNextLevel, hasPremiumPass];
}

/// A reward unlocked at a given season level.
@immutable
class SeasonReward extends Equatable {
  final int level;
  final String description;
  final int coinReward;
  final int gemReward;
  final String? skinId;
  final bool isPremiumOnly;

  const SeasonReward({
    required this.level,
    required this.description,
    this.coinReward = 0,
    this.gemReward = 0,
    this.skinId,
    this.isPremiumOnly = false,
  });

  @override
  List<Object?> get props =>
      [level, description, coinReward, gemReward, skinId, isPremiumOnly];
}
