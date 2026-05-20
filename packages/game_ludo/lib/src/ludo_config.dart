/// Ludo game configuration.
class LudoConfig {
  final int playerCount; // 2, 3, or 4
  final bool requireExactFinish; // Must land exactly on finish
  final bool doubleRollOnSix; // Roll again on 6
  final bool safeSquaresEnabled;
  final int tokensPerPlayer; // Default 4

  const LudoConfig({
    required this.playerCount,
    this.requireExactFinish = true,
    this.doubleRollOnSix = true,
    this.safeSquaresEnabled = true,
    this.tokensPerPlayer = 4,
  }) : assert(playerCount >= 2 && playerCount <= 4);

  Map<String, dynamic> toJson() => {
        'playerCount': playerCount,
        'requireExactFinish': requireExactFinish,
        'doubleRollOnSix': doubleRollOnSix,
        'safeSquaresEnabled': safeSquaresEnabled,
        'tokensPerPlayer': tokensPerPlayer,
      };

  factory LudoConfig.fromJson(Map<String, dynamic> json) => LudoConfig(
        playerCount: json['playerCount'] ?? 4,
        requireExactFinish: json['requireExactFinish'] ?? true,
        doubleRollOnSix: json['doubleRollOnSix'] ?? true,
        safeSquaresEnabled: json['safeSquaresEnabled'] ?? true,
        tokensPerPlayer: json['tokensPerPlayer'] ?? 4,
      );
}
