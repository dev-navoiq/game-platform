import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/config/constants.dart';
import 'package:flutter_app/core/di/locale_provider.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('localeProvider', () {
    test('defaults to null (system locale) with no saved preference', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future<void>.delayed(Duration.zero); // let _load complete
      expect(container.read(localeProvider), isNull);
    });

    test('loads persisted language on startup', () async {
      SharedPreferences.setMockInitialValues(
          {AppConstants.keyLanguageCode: 'hi'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(localeProvider); // instantiate the notifier
      await Future<void>.delayed(Duration.zero); // let _load complete
      expect(container.read(localeProvider), const Locale('hi'));
    });

    test('setLocale persists and clears the preference', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(localeProvider.notifier);
      await notifier.setLocale(const Locale('hi'));
      expect(container.read(localeProvider), const Locale('hi'));

      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.keyLanguageCode), 'hi');

      await notifier.setLocale(null);
      expect(container.read(localeProvider), isNull);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.keyLanguageCode), isNull);
    });
  });

  group('AppLocalizations', () {
    test('every supported app locale has a translation bundle', () {
      for (final locale in supportedAppLocales) {
        expect(AppLocalizations.supportedLocales, contains(locale));
      }
    });

    test('Hindi bundle loads and translates', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('hi'));
      expect(l10n.settingsTitle, 'सेटिंग्स');
      expect(l10n.language, 'भाषा');
      expect(l10n.priceCoins(50), '50 सिक्के');
    });

    test('English bundle loads and translates', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.settingsTitle, 'Settings');
      expect(l10n.priceCoins(50), '50 coins');
    });
  });
}
