import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String username;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int coins;
  final int gems;
  final String subscriptionTier;
  final String? referralCode;
  final String preferredSocialMode;
  final DateTime createdAt;
  final String accountType;
  final String? friendCode;
  final bool discoverable;
  final DateTime? usernameClaimedAt;

  const UserModel({
    required this.id,
    required this.username,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 500,
    this.coins = 0,
    this.gems = 0,
    this.subscriptionTier = 'free',
    this.referralCode,
    this.preferredSocialMode = 'full',
    required this.createdAt,
    this.accountType = 'guest',
    this.friendCode,
    this.discoverable = true,
    this.usernameClaimedAt,
  });

  bool get isGuest => accountType == 'guest';

  /// XXXX-XXXX display formatting for the raw 8-char friend code.
  String? get friendCodeDisplay {
    final code = friendCode;
    if (code == null || code.length != 8) return code;
    return '${code.substring(0, 4)}-${code.substring(4)}';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      xpToNextLevel: json['xp_to_next_level'] as int? ?? 500,
      coins: json['coins'] as int? ?? 0,
      gems: json['gems'] as int? ?? 0,
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      referralCode: json['referral_code'] as String?,
      preferredSocialMode: json['preferred_social_mode'] as String? ?? 'full',
      createdAt: DateTime.parse(json['created_at'] as String),
      accountType: json['account_type'] as String? ?? 'guest',
      friendCode: json['friend_code'] as String?,
      discoverable: json['discoverable'] as bool? ?? true,
      usernameClaimedAt: json['username_claimed_at'] != null
          ? DateTime.parse(json['username_claimed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'level': level,
      'xp': xp,
      'xp_to_next_level': xpToNextLevel,
      'coins': coins,
      'gems': gems,
      'subscription_tier': subscriptionTier,
      'referral_code': referralCode,
      'preferred_social_mode': preferredSocialMode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, username, email, level, xp, coins, gems];
}
