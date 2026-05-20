/// Bot personality archetype — influences risk tolerance and think time.
enum BotPersonality {
  quick,
  balanced,
  thoughtful,
  cautious,
}

extension BotPersonalityExtension on BotPersonality {
  /// Risk tolerance (0–1). Higher = more aggressive play.
  double get riskTolerance => switch (this) {
        BotPersonality.quick => 0.8,
        BotPersonality.balanced => 0.5,
        BotPersonality.thoughtful => 0.4,
        BotPersonality.cautious => 0.2,
      };

  /// Display name for UI.
  String get displayName => switch (this) {
        BotPersonality.quick => 'Quick',
        BotPersonality.balanced => 'Balanced',
        BotPersonality.thoughtful => 'Thoughtful',
        BotPersonality.cautious => 'Cautious',
      };

  /// Avatar identifier for bot profile.
  String get avatarId => switch (this) {
        BotPersonality.quick => 'bot_quick',
        BotPersonality.balanced => 'bot_balanced',
        BotPersonality.thoughtful => 'bot_thoughtful',
        BotPersonality.cautious => 'bot_cautious',
      };
}
