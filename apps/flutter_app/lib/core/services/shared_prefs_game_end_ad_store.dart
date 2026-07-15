import 'package:monetization/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [GameEndAdStore] backed by `shared_preferences`, so the interstitial
/// cadence survives app restarts.
class SharedPrefsGameEndAdStore implements GameEndAdStore {
  static const _kCompletedGames = 'ads.game_end.completed_games';
  static const _kSlotCount = 'ads.game_end.interstitial_slots';
  static const _kLastShownMillis = 'ads.game_end.last_interstitial_millis';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int> getCompletedGameCount() async =>
      (await _prefs).getInt(_kCompletedGames) ?? 0;

  @override
  Future<void> setCompletedGameCount(int value) async =>
      (await _prefs).setInt(_kCompletedGames, value);

  @override
  Future<int> getInterstitialSlotCount() async =>
      (await _prefs).getInt(_kSlotCount) ?? 0;

  @override
  Future<void> setInterstitialSlotCount(int value) async =>
      (await _prefs).setInt(_kSlotCount, value);

  @override
  Future<DateTime?> getLastInterstitialAt() async {
    final millis = (await _prefs).getInt(_kLastShownMillis);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> setLastInterstitialAt(DateTime value) async =>
      (await _prefs).setInt(_kLastShownMillis, value.millisecondsSinceEpoch);
}
