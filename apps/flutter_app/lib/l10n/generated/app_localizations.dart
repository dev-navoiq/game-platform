import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Gathr'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundEffects;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @cardSkin.
  ///
  /// In en, this message translates to:
  /// **'Card Skin'**
  String get cardSkin;

  /// No description provided for @roomTheme.
  ///
  /// In en, this message translates to:
  /// **'Room Theme'**
  String get roomTheme;

  /// No description provided for @preferredSocialMode.
  ///
  /// In en, this message translates to:
  /// **'Preferred Social Mode'**
  String get preferredSocialMode;

  /// No description provided for @socialModeFullDescription.
  ///
  /// In en, this message translates to:
  /// **'Full — Chat + Voice + Emotes'**
  String get socialModeFullDescription;

  /// No description provided for @notificationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notificationPreferences;

  /// No description provided for @notificationPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage alerts, quiet hours'**
  String get notificationPreferencesSubtitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @couldNotCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates'**
  String get couldNotCheckForUpdates;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @priceCoins.
  ///
  /// In en, this message translates to:
  /// **'{count} coins'**
  String priceCoins(int count);

  /// No description provided for @priceGems.
  ///
  /// In en, this message translates to:
  /// **'{count} gems'**
  String priceGems(int count);

  /// No description provided for @chooseAGame.
  ///
  /// In en, this message translates to:
  /// **'Choose a Game'**
  String get chooseAGame;

  /// No description provided for @tournaments.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get tournaments;

  /// No description provided for @resumeGame.
  ///
  /// In en, this message translates to:
  /// **'Resume Game'**
  String get resumeGame;

  /// No description provided for @resumeInGame.
  ///
  /// In en, this message translates to:
  /// **'A game is in progress'**
  String get resumeInGame;

  /// No description provided for @resumeInLobby.
  ///
  /// In en, this message translates to:
  /// **'You\'re waiting in a lobby'**
  String get resumeInLobby;

  /// No description provided for @resumeSpectating.
  ///
  /// In en, this message translates to:
  /// **'You\'re spectating a game'**
  String get resumeSpectating;

  /// No description provided for @resumeTapToRejoin.
  ///
  /// In en, this message translates to:
  /// **'Tap to rejoin'**
  String get resumeTapToRejoin;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @dailyChallenges.
  ///
  /// In en, this message translates to:
  /// **'Daily Challenges'**
  String get dailyChallenges;

  /// No description provided for @resetsIn.
  ///
  /// In en, this message translates to:
  /// **'Resets in {hours}h'**
  String resetsIn(int hours);

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get games;

  /// Player count shown under a game tile, e.g. '2-4 players'
  ///
  /// In en, this message translates to:
  /// **'{range} players'**
  String playerCountRange(String range);

  /// No description provided for @lobbyTitle.
  ///
  /// In en, this message translates to:
  /// **'{gameName} Lobby'**
  String lobbyTitle(String gameName);

  /// No description provided for @joinByCode.
  ///
  /// In en, this message translates to:
  /// **'Join by Code'**
  String get joinByCode;

  /// No description provided for @practiceVsBots.
  ///
  /// In en, this message translates to:
  /// **'Practice vs Bots'**
  String get practiceVsBots;

  /// No description provided for @createRoom.
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoom;

  /// No description provided for @howManyPlayers.
  ///
  /// In en, this message translates to:
  /// **'How many players?'**
  String get howManyPlayers;

  /// No description provided for @ohHellPlayerCountHint.
  ///
  /// In en, this message translates to:
  /// **'Oh Hell needs 4 to 6 players. You can add bots in the room.'**
  String get ohHellPlayerCountHint;

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'players'**
  String get players;

  /// No description provided for @roomJoinComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Room {code} — join via code coming soon'**
  String roomJoinComingSoon(String code);

  /// No description provided for @gameNameTwentyNine.
  ///
  /// In en, this message translates to:
  /// **'Twenty-Nine'**
  String get gameNameTwentyNine;

  /// No description provided for @gameNameOhHell.
  ///
  /// In en, this message translates to:
  /// **'Oh Hell'**
  String get gameNameOhHell;

  /// No description provided for @gameNameHearts.
  ///
  /// In en, this message translates to:
  /// **'Hearts'**
  String get gameNameHearts;

  /// No description provided for @gameNameSpades.
  ///
  /// In en, this message translates to:
  /// **'Spades'**
  String get gameNameSpades;

  /// No description provided for @gameNameBridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get gameNameBridge;

  /// No description provided for @gameNameChess.
  ///
  /// In en, this message translates to:
  /// **'Chess'**
  String get gameNameChess;

  /// No description provided for @gameNameLudo.
  ///
  /// In en, this message translates to:
  /// **'Ludo'**
  String get gameNameLudo;

  /// No description provided for @gameNameSequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get gameNameSequence;

  /// No description provided for @gameNameRummy.
  ///
  /// In en, this message translates to:
  /// **'Rummy'**
  String get gameNameRummy;

  /// No description provided for @gameNameGeneric.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get gameNameGeneric;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
