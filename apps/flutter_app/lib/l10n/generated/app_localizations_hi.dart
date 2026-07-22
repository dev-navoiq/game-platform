// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Gathr';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get language => 'भाषा';

  @override
  String get languageSystemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get darkMode => 'डार्क मोड';

  @override
  String get soundEffects => 'ध्वनि प्रभाव';

  @override
  String get music => 'संगीत';

  @override
  String get cardSkin => 'कार्ड स्किन';

  @override
  String get roomTheme => 'रूम थीम';

  @override
  String get preferredSocialMode => 'पसंदीदा सोशल मोड';

  @override
  String get socialModeFullDescription => 'पूर्ण — चैट + वॉइस + इमोट्स';

  @override
  String get notificationPreferences => 'सूचना प्राथमिकताएँ';

  @override
  String get notificationPreferencesSubtitle =>
      'अलर्ट और शांत घंटे प्रबंधित करें';

  @override
  String get appVersion => 'ऐप संस्करण';

  @override
  String get update => 'अपडेट करें';

  @override
  String get checking => 'जाँच हो रही है…';

  @override
  String get couldNotCheckForUpdates => 'अपडेट की जाँच नहीं हो सकी';

  @override
  String get free => 'मुफ़्त';

  @override
  String priceCoins(int count) {
    return '$count सिक्के';
  }

  @override
  String priceGems(int count) {
    return '$count रत्न';
  }

  @override
  String get chooseAGame => 'कोई खेल चुनें';

  @override
  String get tournaments => 'टूर्नामेंट';

  @override
  String get resumeGame => 'खेल जारी रखें';

  @override
  String get resumeInGame => 'एक खेल चल रहा है';

  @override
  String get resumeInLobby => 'आप लॉबी में प्रतीक्षा कर रहे हैं';

  @override
  String get resumeSpectating => 'आप एक खेल देख रहे हैं';

  @override
  String get resumeTapToRejoin => 'फिर से जुड़ने के लिए टैप करें';

  @override
  String get friends => 'दोस्त';

  @override
  String get seeAll => 'सभी देखें';

  @override
  String get dailyChallenges => 'दैनिक चुनौतियाँ';

  @override
  String resetsIn(int hours) {
    return '$hours घंटे में रीसेट';
  }

  @override
  String get games => 'खेल';

  @override
  String playerCountRange(String range) {
    return '$range खिलाड़ी';
  }

  @override
  String lobbyTitle(String gameName) {
    return '$gameName लॉबी';
  }

  @override
  String get joinByCode => 'कोड से जुड़ें';

  @override
  String get practiceVsBots => 'बॉट्स के साथ अभ्यास';

  @override
  String get createRoom => 'रूम बनाएँ';

  @override
  String get howManyPlayers => 'कितने खिलाड़ी?';

  @override
  String get ohHellPlayerCountHint =>
      'ओह हेल के लिए 4 से 6 खिलाड़ी चाहिए। आप रूम में बॉट जोड़ सकते हैं।';

  @override
  String get playerCountHint => 'खाली सीटें रूम में बॉट्स से भरी जा सकती हैं।';

  @override
  String get gameLength => 'गेम की लंबाई';

  @override
  String get gameLengthQuick => 'क्विक';

  @override
  String get gameLengthOneWay => 'एक तरफ़ा';

  @override
  String get gameLengthClassic => 'क्लासिक';

  @override
  String roundsCount(int count) {
    return '$count राउंड';
  }

  @override
  String get startWhenFull => 'पूरा भरते ही अपने आप शुरू करें';

  @override
  String get players => 'खिलाड़ी';

  @override
  String roomJoinComingSoon(String code) {
    return 'रूम $code — कोड से जुड़ना जल्द आ रहा है';
  }

  @override
  String get gameNameTwentyNine => 'उनतीस (29)';

  @override
  String get gameNameOhHell => 'ओह हेल';

  @override
  String get gameNameHearts => 'हार्ट्स';

  @override
  String get gameNameSpades => 'स्पेड्स';

  @override
  String get gameNameBridge => 'ब्रिज';

  @override
  String get gameNameChess => 'शतरंज';

  @override
  String get gameNameLudo => 'लूडो';

  @override
  String get gameNameSequence => 'सीक्वेंस';

  @override
  String get gameNameRummy => 'रम्मी';

  @override
  String get gameNameGeneric => 'खेल';
}
