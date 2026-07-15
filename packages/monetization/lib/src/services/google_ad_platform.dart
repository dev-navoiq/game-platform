import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_platform.dart';

/// AdMob ad-unit IDs for the placements this app uses.
///
/// Inject Google's official TEST unit IDs in dev/staging and the real
/// unit IDs in production (see `EnvConfig` in the app layer).
class GoogleAdUnitIds {
  final String banner;
  final String interstitial;

  const GoogleAdUnitIds({
    required this.banner,
    required this.interstitial,
  });
}

/// Real [AdPlatform] backed by the Google Mobile Ads SDK.
///
/// The SDK is initialized lazily on the first ad load so that paying
/// (ad-free) users never pay the SDK startup cost — construct this object
/// freely; nothing happens until [loadBanner] or [showInterstitial] is
/// called.
class GoogleAdPlatform implements AdPlatform {
  GoogleAdPlatform({required this.adUnitIds});

  final GoogleAdUnitIds adUnitIds;

  Future<bool>? _initFuture;
  bool _disposed = false;
  InterstitialAd? _pendingInterstitial;

  /// Lazily initialize the Mobile Ads SDK exactly once.
  ///
  /// Returns `false` (instead of throwing) if the SDK cannot start, so
  /// callers can degrade gracefully to no-ads.
  Future<bool> ensureInitialized() {
    // TODO(consent): run UMP consent gathering + iOS ATT prompt here,
    // before MobileAds initialization / any ad load. Out of scope for now.
    return _initFuture ??= MobileAds.instance
        .initialize()
        .then((_) => true)
        .catchError((Object _) => false);
  }

  /// Load a banner ad and return it once it has successfully loaded.
  ///
  /// Returns `null` if the SDK failed to initialize or the ad failed to
  /// load (e.g. no fill, no network). The caller owns the returned ad and
  /// is responsible for rendering it (via `AdWidget`) and disposing it.
  Future<BannerAd?> loadBanner({AdSize size = AdSize.banner}) async {
    if (_disposed) return null;
    if (!await ensureInitialized()) return null;

    final completer = Completer<BannerAd?>();
    final banner = BannerAd(
      adUnitId: adUnitIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    await banner.load();
    return completer.future;
  }

  @override
  Future<void> showBanner() async {
    // Banners are view-based: the UI layer calls [loadBanner] and renders
    // the returned ad with an `AdWidget`. Nothing to do here.
  }

  @override
  Future<void> showInterstitial() async {
    if (_disposed) return;
    if (!await ensureInitialized()) return;

    // TODO(consent): interstitial loads must also be gated on UMP consent.
    final loadCompleter = Completer<InterstitialAd?>();
    await InterstitialAd.load(
      adUnitId: adUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!loadCompleter.isCompleted) loadCompleter.complete(ad);
        },
        onAdFailedToLoad: (error) {
          if (!loadCompleter.isCompleted) loadCompleter.complete(null);
        },
      ),
    );

    final ad = await loadCompleter.future;
    if (ad == null) return; // No fill / no network — degrade silently.
    if (_disposed) {
      ad.dispose();
      return;
    }

    _pendingInterstitial = ad;
    final dismissed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );
    await ad.show();
    await dismissed.future;
    _pendingInterstitial = null;
  }

  @override
  Future<bool> showRewarded() async {
    // Rewarded video is intentionally not implemented yet: it requires the
    // server-side-verification edge function (separate work stream).
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingInterstitial?.dispose();
    _pendingInterstitial = null;
  }
}
