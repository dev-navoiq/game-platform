/// What to show (if anything) at a game-end interstitial opportunity.
enum GameEndAdDecision {
  /// Show nothing this game.
  none,

  /// Show a real (AdMob) interstitial.
  interstitial,

  /// Show the in-house Pro-upsell overlay instead of a network ad.
  houseAd,
}

/// Persistence for the game-end interstitial cadence counters.
///
/// The app backs this with `shared_preferences`; tests use
/// [InMemoryGameEndAdStore].
abstract class GameEndAdStore {
  Future<int> getCompletedGameCount();
  Future<void> setCompletedGameCount(int value);

  Future<int> getInterstitialSlotCount();
  Future<void> setInterstitialSlotCount(int value);

  Future<DateTime?> getLastInterstitialAt();
  Future<void> setLastInterstitialAt(DateTime value);
}

/// Simple in-memory [GameEndAdStore] for tests and mock mode.
class InMemoryGameEndAdStore implements GameEndAdStore {
  int _completedGames = 0;
  int _slots = 0;
  DateTime? _lastInterstitialAt;

  @override
  Future<int> getCompletedGameCount() async => _completedGames;

  @override
  Future<void> setCompletedGameCount(int value) async {
    _completedGames = value;
  }

  @override
  Future<int> getInterstitialSlotCount() async => _slots;

  @override
  Future<void> setInterstitialSlotCount(int value) async {
    _slots = value;
  }

  @override
  Future<DateTime?> getLastInterstitialAt() async => _lastInterstitialAt;

  @override
  Future<void> setLastInterstitialAt(DateTime value) async {
    _lastInterstitialAt = value;
  }
}

/// Cadence policy for the game-end interstitial (free tier only).
///
/// Rules:
/// - An interstitial slot opens only every [gamesPerInterstitial]-th
///   completed game.
/// - At least [minInterval] must have elapsed since the last interstitial
///   (of either kind). If not, the slot is skipped (not consumed).
/// - Every [houseAdSlotEvery]-rd consumed slot serves the in-house
///   Pro-upsell overlay instead of a network ad.
/// - If the user is ad-fatigued (see [AdService] fatigue constants), the
///   slot is skipped entirely.
///
/// The caller is responsible for tier gating (never call this for Pro/Max)
/// and for only invoking [onGameCompleted] when a game has actually
/// finished — never mid-game.
class GameEndInterstitialCadence {
  /// A slot opens every N completed games.
  static const int gamesPerInterstitial = 2;

  /// Minimum time between interstitials (network or house).
  static const Duration minInterval = Duration(minutes: 3);

  /// Every N-th consumed slot serves the house ad (Pro upsell).
  static const int houseAdSlotEvery = 3;

  final GameEndAdStore _store;
  final DateTime Function() _now;
  final Future<bool> Function() _isFatigued;

  GameEndInterstitialCadence(
    this._store, {
    DateTime Function()? now,
    Future<bool> Function()? isFatigued,
  })  : _now = now ?? DateTime.now,
        _isFatigued = isFatigued ?? _neverFatigued;

  static Future<bool> _neverFatigued() async => false;

  /// Record a completed game and decide what (if anything) to show.
  Future<GameEndAdDecision> onGameCompleted() async {
    // Count every completed game, even ones that show nothing.
    final games = await _store.getCompletedGameCount() + 1;
    await _store.setCompletedGameCount(games);

    // Only every Nth completed game opens an interstitial slot.
    if (games % gamesPerInterstitial != 0) return GameEndAdDecision.none;

    // Enforce the minimum gap. A skipped slot is NOT consumed, so the
    // house-ad rotation is unaffected.
    final last = await _store.getLastInterstitialAt();
    if (last != null && _now().difference(last) < minInterval) {
      return GameEndAdDecision.none;
    }

    // Fatigued users get a break; the slot is not consumed.
    if (await _isFatigued()) return GameEndAdDecision.none;

    // Consume the slot.
    final slot = await _store.getInterstitialSlotCount() + 1;
    await _store.setInterstitialSlotCount(slot);
    await _store.setLastInterstitialAt(_now());

    return slot % houseAdSlotEvery == 0
        ? GameEndAdDecision.houseAd
        : GameEndAdDecision.interstitial;
  }
}
