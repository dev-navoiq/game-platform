import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:monetization/monetization.dart';

import '../../core/di/monetization_providers.dart';
import '../../core/services/ad_mode.dart';
import '../../core/services/house_ads/house_ad_creative.dart';
import '../../core/theme/colors.dart';
import 'house_banner_ad.dart';

/// Banner ad for free-tier users (lobby placement).
///
/// - Hidden entirely for Pro/Max subscribers ([showAdsProvider] is false).
/// - In [AdMode.house], renders a natively-drawn house creative (rotated
///   round-robin) in the same slot, with the same visibility rules.
/// - Renders a real AdMob banner when the ad platform is [GoogleAdPlatform]
///   (Android/iOS devices, [AdMode.google]).
/// - Falls back to the glass placeholder in mock mode (tests, unsupported
///   platforms) and while the real ad is loading or failed to fill.
class BannerAdWidget extends ConsumerStatefulWidget {
  final bool isVisible;

  const BannerAdWidget({super.key, this.isVisible = true});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loadStarted = false;
  HouseAdCreative? _houseCreative;
  bool _houseLoadStarted = false;

  /// Pick the next house creative (round-robin, persisted) exactly once per
  /// widget mount, so rebuilds don't advance the rotation.
  void _maybeLoadHouseCreative() {
    if (_houseLoadStarted) return;
    _houseLoadStarted = true;
    ref.read(houseAdRotationProvider).next().then((creative) {
      if (!mounted) return;
      setState(() => _houseCreative = creative);
    });
  }

  void _maybeLoad() {
    if (_loadStarted) return;
    if (!widget.isVisible) return;
    // Never touch the ad SDK for ad-free tiers — this is what keeps the
    // Mobile Ads SDK from ever initializing for paying users.
    if (ref.read(showAdsProvider) != true) return;
    final platform = ref.read(adPlatformProvider);
    if (platform is! GoogleAdPlatform) return;

    _loadStarted = true;
    // TODO(consent): UMP consent + iOS ATT should run before the first ad
    // load in production (out of scope this pass).
    platform.loadBanner().then((ad) {
      if (!mounted) {
        ad?.dispose();
        return;
      }
      setState(() => _bannerAd = ad);
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAds = ref.watch(showAdsProvider);
    if (!widget.isVisible || !showAds) return const SizedBox.shrink();

    // House mode: draw our own creative in the same slot (same size, same
    // visibility rules) instead of touching the ad SDK.
    if (ref.watch(adModeProvider) == AdMode.house) {
      _maybeLoadHouseCreative();
      final creative = _houseCreative;
      if (creative != null) {
        return Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          child: HouseBannerAd(creative: creative),
        );
      }
      // Fall through to the glass placeholder while the rotation resolves.
      return _placeholder();
    }

    _maybeLoad();

    final ad = _bannerAd;
    if (ad != null) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      );
    }

    // Placeholder: mock mode, still loading, or no fill.
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ad_units,
                size: 18, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(
              'Ad Placeholder',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
