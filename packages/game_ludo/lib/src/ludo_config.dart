/// Ludo game configuration.
class LudoConfig {
  final int playerCount; // 2, 3, or 4
  final bool requireExactFinish; // Must land exactly on finish
  final bool doubleRollOnSix; // Roll again on 6
  final bool bonusTurnOnCapture; // Roll again after capturing an opponent
  final bool safeSquaresEnabled;
  final int tokensPerPlayer; // Default 4

  const LudoConfig({
    required this.playerCount,
    this.requireExactFinish = true,
    this.doubleRollOnSix = true,
    this.bonusTurnOnCapture = true,
    this.safeSquaresEnabled = true,
    this.tokensPerPlayer = 4,
  }) : assert(playerCount >= 2 && playerCount <= 4);

  Map<String, dynamic> toJson() => {
        'playerCount': playerCount,
        'requireExactFinish': requireExactFinish,
        'doubleRollOnSix': doubleRollOnSix,
        'bonusTurnOnCapture': bonusTurnOnCapture,
        'safeSquaresEnabled': safeSquaresEnabled,
        'tokensPerPlayer': tokensPerPlayer,
      };

  factory LudoConfig.fromJson(Map<String, dynamic> json) => LudoConfig(
        playerCount: json['playerCount'] ?? 4,
        requireExactFinish: json['requireExactFinish'] ?? true,
        doubleRollOnSix: json['doubleRollOnSix'] ?? true,
        bonusTurnOnCapture: json['bonusTurnOnCapture'] ?? true,
        safeSquaresEnabled: json['safeSquaresEnabled'] ?? true,
        tokensPerPlayer: json['tokensPerPlayer'] ?? 4,
      );
}
