import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:monetization/monetization.dart';

import '../../shared/widgets/house_interstitial_overlay.dart';
import '../../shared/widgets/interstitial_ad_overlay.dart';
import '../di/monetization_providers.dart';
import '../di/providers.dart';
import '../routing/routes.dart';
import 'ad_mode.dart';

/// Orchestrates the game-end interstitial for free-tier users.
///
/// Call [onGameFinished] exactly once per completed game, from the
/// game-over UI (never mid-game). Tier gating, cadence (every 2nd game,
/// 3-minute gap, every 3rd slot = house ad) and fatigue are all handled
/// here — callers don't need any conditions.
class GameEndAdController {
  GameEndAdController(this._ref);

  final Ref _ref;

  Future<void> onGameFinished(BuildContext context) async {
    try {
      await _onGameFinished(context);
    } catch (_) {
      // Ads must never break the game-over flow — degrade to no ad on any
      // failure (SDK error, storage unavailable, etc.).
    }
  }

  Future<void> _onGameFinished(BuildContext context) async {
    // Pro/Max never see ads; nothing is counted or loaded for them.
    if (_ref.read(showAdsProvider) != true) return;

    final decision =
        await _ref.read(gameEndAdCadenceProvider).onGameCompleted();
    if (decision == GameEndAdDecision.none) return;
    if (!context.mounted) return;

    switch (decision) {
      case GameEndAdDecision.none:
        return;

      case GameEndAdDecision.houseAd:
        await _showHouseAd(context);

      case GameEndAdDecision.interstitial:
        await _showInterstitialSlot(context);
    }

    _recordImpression(AdPlacement.gameEndInterstitial);
  }

  /// Serve the interstitial slot for the current [AdMode]:
  /// - `house`: full-screen house creative (round-robin rotation).
  /// - `google`: real AdMob interstitial.
  /// - `mock` (tests / unsupported platforms): the Pro-upsell overlay as a
  ///   visible stand-in instead of an invisible delay.
  Future<void> _showInterstitialSlot(BuildContext context) async {
    final mode = _ref.read(adModeProvider);
    if (mode == AdMode.house) {
      await _showHouseInterstitial(context);
      return;
    }
    final platform = _ref.read(adPlatformProvider);
    if (mode == AdMode.google && platform is GoogleAdPlatform) {
      // TODO(consent): UMP consent + iOS ATT must run before this load
      // in production (handled inside GoogleAdPlatform when added).
      await platform.showInterstitial();
    } else if (context.mounted) {
      // Mock mode: show the Pro-upsell overlay as a visible stand-in
      // instead of an invisible delay.
      await _showHouseAd(context);
    }
  }

  /// Interstitial when the user starts a "Practice vs Bots" game.
  ///
  /// Tier-gated like every ad (Pro/Max see nothing) but deliberately NOT
  /// cadence-limited: every practice start serves the slot, so the team can
  /// exercise the full interstitial pipeline without playing a game to the
  /// end. Add a frequency rule here before wide release if it feels heavy.
  Future<void> onPracticeStart(BuildContext context) async {
    try {
      if (_ref.read(showAdsProvider) != true) return;
      await _showInterstitialSlot(context);
      _recordImpression(AdPlacement.gameStartInterstitial);
    } catch (_) {
      // Ads must never block starting a game.
    }
  }

  /// Dev-only (used by the `/dev/ads` gallery): serve the game-end
  /// interstitial slot immediately, bypassing tier gating and cadence.
  /// Never call this from production game flows.
  Future<void> debugShowGameEndInterstitial(BuildContext context) {
    return _showInterstitialSlot(context);
  }

  Future<void> _showHouseInterstitial(BuildContext context) async {
    final creative = await _ref.read(houseAdRotationProvider).next();
    if (!context.mounted) return;
    await HouseInterstitialOverlay.show(context: context, creative: creative);
  }

  Future<void> _showHouseAd(BuildContext context) {
    return InterstitialAdOverlay.show(
      context: context,
      onUpgrade: () {
        // Close the overlay, then take the user to the subscription page.
        Navigator.of(context, rootNavigator: true).pop();
        context.push(AppRoutes.subscription);
      },
    );
  }

  /// Best-effort analytics/rate-limit record; never blocks or throws.
  void _recordImpression(AdPlacement placement) {
    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    Future<void>(() async {
      try {
        await _ref.read(adServiceProvider).recordImpression(
              userId,
              AdType.interstitial,
              placement,
            );
      } catch (_) {
        // Analytics only — never surface failures to the game-over flow.
      }
    });
  }
}

/// Provider for the game-end ad controller.
final gameEndAdControllerProvider = Provider<GameEndAdController>((ref) {
  return GameEndAdController(ref);
});
