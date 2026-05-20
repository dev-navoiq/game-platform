/// Sequence game configuration.
class SequenceConfig {
  final int playerCount; // 2, 3, or 4 (4 = 2v2 teams)
  final int sequencesToWin; // Default: 2 for 2P, 1 for 3P, 2 for 4P
  final bool allowRemoval; // One-eyed jacks can remove chips
  final int handSize; // 7 for 2-3 players, 6 for 4+ players

  const SequenceConfig({
    required this.playerCount,
    int? sequencesToWin,
    this.allowRemoval = true,
    int? handSize,
  })  : sequencesToWin = sequencesToWin ?? (playerCount == 3 ? 1 : 2),
        handSize = handSize ?? (playerCount <= 3 ? 7 : 6);

  Map<String, dynamic> toJson() => {
        'playerCount': playerCount,
        'sequencesToWin': sequencesToWin,
        'allowRemoval': allowRemoval,
        'handSize': handSize,
      };

  factory SequenceConfig.fromJson(Map<String, dynamic> json) => SequenceConfig(
        playerCount: json['playerCount'] ?? 2,
        sequencesToWin: json['sequencesToWin'],
        allowRemoval: json['allowRemoval'] ?? true,
        handSize: json['handSize'],
      );
}
