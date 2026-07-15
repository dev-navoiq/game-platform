import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// Languages the app ships translations for. Order is the order shown in the
/// Settings picker. Add a Locale here + a lib/l10n/app_<code>.arb file to
/// introduce a new language.
const supportedAppLocales = [
  Locale('en'),
  Locale('hi'),
];

/// Native-script display names for the language picker. Kept out of the ARB
/// files on purpose: a language's own name should never be translated.
String localeDisplayName(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'English';
    case 'hi':
      return 'हिन्दी';
    default:
      return locale.languageCode;
  }
}

/// App locale override. `null` means follow the device locale (Flutter then
/// resolves to the closest supported locale, falling back to English).
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(AppConstants.keyLanguageCode);
      if (code != null && mounted) {
        state = Locale(code);
      }
    } catch (_) {
      // Prefs unavailable (e.g. tests) — stay on system locale.
    }
  }

  /// Pass `null` to return to the system locale.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(AppConstants.keyLanguageCode);
      } else {
        await prefs.setString(AppConstants.keyLanguageCode, locale.languageCode);
      }
    } catch (_) {
      // Persisting failed — the choice still applies for this session.
    }
  }
}
