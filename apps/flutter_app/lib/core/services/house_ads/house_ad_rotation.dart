import 'package:shared_preferences/shared_preferences.dart';

import 'house_ad_catalog.dart';
import 'house_ad_creative.dart';

/// Persistence for the house-ad round-robin cursor.
///
/// The app backs this with `shared_preferences` (so rotation survives
/// restarts); tests use [InMemoryHouseAdRotationStore].
abstract class HouseAdRotationStore {
  /// Index (into the catalog) of the next creative to serve. 0 when never
  /// stored.
  Future<int> getNextIndex();
  Future<void> setNextIndex(int value);
}

/// Simple in-memory [HouseAdRotationStore] for tests.
class InMemoryHouseAdRotationStore implements HouseAdRotationStore {
  int _nextIndex = 0;

  @override
  Future<int> getNextIndex() async => _nextIndex;

  @override
  Future<void> setNextIndex(int value) async {
    _nextIndex = value;
  }
}

/// [HouseAdRotationStore] backed by `shared_preferences`, following the
/// same pattern as `SharedPrefsGameEndAdStore`.
class SharedPrefsHouseAdRotationStore implements HouseAdRotationStore {
  static const _kNextIndex = 'ads.house.next_creative_index';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int> getNextIndex() async => (await _prefs).getInt(_kNextIndex) ?? 0;

  @override
  Future<void> setNextIndex(int value) async =>
      (await _prefs).setInt(_kNextIndex, value);
}

/// Round-robin rotation over the house creative catalog with last-shown
/// persistence: every call to [next] serves the creative after the one
/// served last time, wrapping at the end of the catalog — across app
/// restarts when backed by [SharedPrefsHouseAdRotationStore].
class HouseAdRotation {
  HouseAdRotation(this._store, {List<HouseAdCreative>? catalog})
      : catalog = catalog ?? kHouseAdCatalog,
        assert(catalog == null || catalog.isNotEmpty,
            'House ad catalog must not be empty');

  final HouseAdRotationStore _store;

  /// The creatives being rotated, in serving order.
  final List<HouseAdCreative> catalog;

  /// Return the next creative in round-robin order and persist the cursor.
  Future<HouseAdCreative> next() async {
    final index = (await _store.getNextIndex()) % catalog.length;
    await _store.setNextIndex(index + 1);
    return catalog[index];
  }
}
