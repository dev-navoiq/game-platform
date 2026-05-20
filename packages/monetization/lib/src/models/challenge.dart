import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Whether a challenge resets daily or weekly.
enum ChallengeType { daily, weekly }

/// A challenge template that defines what the user must achieve.
@immutable
class Challenge extends Equatable {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int target;
  final int rewardCoins;
  final int rewardGems;
  final DateTime createdAt;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.rewardCoins,
    this.rewardGems = 0,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, title, description, type, target, rewardCoins, rewardGems, createdAt];
}

/// A user's progress toward a specific challenge.
@immutable
class UserChallenge extends Equatable {
  final String challengeId;
  final String userId;
  final int current;
  final bool isCompleted;
  final bool canReroll;

  /// The associated challenge template (may be attached for display).
  final Challenge? challenge;

  const UserChallenge({
    required this.challengeId,
    required this.userId,
    required this.current,
    this.isCompleted = false,
    this.canReroll = true,
    this.challenge,
  });

  /// Progress as a fraction from 0.0 to 1.0.
  double get progressPercent {
    if (challenge == null || challenge!.target <= 0) return 0;
    return (current / challenge!.target).clamp(0.0, 1.0);
  }

  UserChallenge copyWith({
    String? challengeId,
    String? userId,
    int? current,
    bool? isCompleted,
    bool? canReroll,
    Challenge? challenge,
  }) =>
      UserChallenge(
        challengeId: challengeId ?? this.challengeId,
        userId: userId ?? this.userId,
        current: current ?? this.current,
        isCompleted: isCompleted ?? this.isCompleted,
        canReroll: canReroll ?? this.canReroll,
        challenge: challenge ?? this.challenge,
      );

  @override
  List<Object?> get props =>
      [challengeId, userId, current, isCompleted, canReroll];
}
