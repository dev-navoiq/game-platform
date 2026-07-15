// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Gathr';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get soundEffects => 'Sound Effects';

  @override
  String get music => 'Music';

  @override
  String get cardSkin => 'Card Skin';

  @override
  String get roomTheme => 'Room Theme';

  @override
  String get preferredSocialMode => 'Preferred Social Mode';

  @override
  String get socialModeFullDescription => 'Full — Chat + Voice + Emotes';

  @override
  String get notificationPreferences => 'Notification Preferences';

  @override
  String get notificationPreferencesSubtitle => 'Manage alerts, quiet hours';

  @override
  String get appVersion => 'App Version';

  @override
  String get update => 'Update';

  @override
  String get checking => 'Checking…';

  @override
  String get couldNotCheckForUpdates => 'Could not check for updates';

  @override
  String get free => 'Free';

  @override
  String priceCoins(int count) {
    return '$count coins';
  }

  @override
  String priceGems(int count) {
    return '$count gems';
  }

  @override
  String get chooseAGame => 'Choose a Game';

  @override
  String get tournaments => 'Tournaments';

  @override
  String get resumeGame => 'Resume Game';

  @override
  String get resumeInGame => 'A game is in progress';

  @override
  String get resumeInLobby => 'You\'re waiting in a lobby';

  @override
  String get resumeSpectating => 'You\'re spectating a game';

  @override
  String get resumeTapToRejoin => 'Tap to rejoin';

  @override
  String get friends => 'Friends';

  @override
  String get seeAll => 'See All';

  @override
  String get dailyChallenges => 'Daily Challenges';

  @override
  String resetsIn(int hours) {
    return 'Resets in ${hours}h';
  }

  @override
  String get games => 'Games';

  @override
  String playerCountRange(String range) {
    return '$range players';
  }

  @override
  String lobbyTitle(String gameName) {
    return '$gameName Lobby';
  }

  @override
  String get joinByCode => 'Join by Code';

  @override
  String get practiceVsBots => 'Practice vs Bots';

  @override
  String get createRoom => 'Create Room';

  @override
  String get howManyPlayers => 'How many players?';

  @override
  String get ohHellPlayerCountHint =>
      'Oh Hell needs 4 to 6 players. You can add bots in the room.';

  @override
  String get players => 'players';

  @override
  String roomJoinComingSoon(String code) {
    return 'Room $code — join via code coming soon';
  }

  @override
  String get gameNameTwentyNine => 'Twenty-Nine';

  @override
  String get gameNameOhHell => 'Oh Hell';

  @override
  String get gameNameHearts => 'Hearts';

  @override
  String get gameNameSpades => 'Spades';

  @override
  String get gameNameBridge => 'Bridge';

  @override
  String get gameNameChess => 'Chess';

  @override
  String get gameNameLudo => 'Ludo';

  @override
  String get gameNameSequence => 'Sequence';

  @override
  String get gameNameRummy => 'Rummy';

  @override
  String get gameNameGeneric => 'Game';
}
