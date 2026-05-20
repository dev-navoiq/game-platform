/// Difficulty levels for bot players.
enum BotDifficulty {
  beginner,
  easy,
  medium,
  hard,
  expert,
  master,
}

extension BotDifficultyExtension on BotDifficulty {
  /// Probability (0–1) of making the optimal move.
  double get accuracy => switch (this) {
        BotDifficulty.beginner => 0.3,
        BotDifficulty.easy => 0.5,
        BotDifficulty.medium => 0.7,
        BotDifficulty.hard => 0.85,
        BotDifficulty.expert => 0.95,
        BotDifficulty.master => 1.0,
      };

  /// Search depth for lookahead algorithms (chess minimax, etc.).
  int get searchDepth => switch (this) {
        BotDifficulty.beginner => 1,
        BotDifficulty.easy => 2,
        BotDifficulty.medium => 3,
        BotDifficulty.hard => 4,
        BotDifficulty.expert => 5,
        BotDifficulty.master => 6,
      };

  /// Display name for UI.
  String get displayName => switch (this) {
        BotDifficulty.beginner => 'Beginner',
        BotDifficulty.easy => 'Easy',
        BotDifficulty.medium => 'Medium',
        BotDifficulty.hard => 'Hard',
        BotDifficulty.expert => 'Expert',
        BotDifficulty.master => 'Master',
      };
}
