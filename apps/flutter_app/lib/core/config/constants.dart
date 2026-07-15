class AppConstants {
  AppConstants._();

  // Timing
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
  static const Duration cardDealDelay = Duration(milliseconds: 150);

  // Sizes
  static const double borderRadius = 16.0;
  static const double cardAspectRatio = 0.7;
  static const double glassBlur = 18.0;

  // Game
  static const int maxRoomPlayers = 8;
  static const int maxChatMessages = 100;
  static const int turnTimeoutSeconds = 30;
  static const int maxChatMessageLength = 500;

  // Storage keys
  static const String keyThemeMode = 'theme_mode';
  static const String keySoundEnabled = 'sound_enabled';
  static const String keyMusicEnabled = 'music_enabled';
  static const String keyCardSkin = 'card_skin';
  static const String keyRoomSkin = 'room_skin';
  static const String keySocialMode = 'social_mode';
  static const String keyLanguageCode = 'language_code';
}
