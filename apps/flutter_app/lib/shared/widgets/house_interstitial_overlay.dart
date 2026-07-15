import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/house_ads/house_ad_creative.dart';
import '../../core/theme/colors.dart';
import 'glass_button.dart';

/// Full-screen house interstitial: a full-bleed "Refined Crystal" creative
/// served in the same slot AdMob interstitials use (when the ad mode is
/// `house`).
///
/// Standard interstitial UX: the close (X) affordance appears after
/// [closeDelay] (~3s), the CTA navigates to the creative's route, and the
/// ad label ("Ad · Gathr" / "Sponsored · Demo") is always visible.
///
/// Shown via [show], which follows the same `showDialog` pattern as
/// `InterstitialAdOverlay` — no new navigation mechanism.
class HouseInterstitialOverlay extends StatefulWidget {
  final HouseAdCreative creative;
  final Duration closeDelay;
  final VoidCallback onClose;

  /// Called when the CTA is tapped, after the overlay has closed itself.
  /// Defaults to pushing the creative's route (if any).
  final VoidCallback? onCta;

  const HouseInterstitialOverlay({
    super.key,
    required this.creative,
    required this.onClose,
    this.closeDelay = const Duration(seconds: 3),
    this.onCta,
  });

  static Future<void> show({
    required BuildContext context,
    required HouseAdCreative creative,
    Duration closeDelay = const Duration(seconds: 3),
    VoidCallback? onCta,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      useSafeArea: false,
      builder: (dialogContext) => HouseInterstitialOverlay(
        creative: creative,
        closeDelay: closeDelay,
        onClose: () => Navigator.of(dialogContext).pop(),
        onCta: onCta ??
            () {
              // Close the overlay, then deep-link from the *outer* context
              // (the dialog's own context is gone after the pop).
              Navigator.of(dialogContext).pop();
              final route = creative.route;
              if (route != null) context.push(route);
            },
      ),
    );
  }

  @override
  State<HouseInterstitialOverlay> createState() =>
      _HouseInterstitialOverlayState();
}

class _HouseInterstitialOverlayState extends State<HouseInterstitialOverlay> {
  bool _closable = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.closeDelay, () {
      if (mounted) setState(() => _closable = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creative = widget.creative;
    final accent = creative.accentColor;
    final topPadding = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Full-bleed felt background with an accent glow behind the art.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.feltMid, AppColors.feltDark],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.25),
                  radius: 0.9,
                  colors: [accent.withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ),

          // Creative content.
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Art: big emoji/icon in a glass ring.
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: creative.emoji != null
                          ? Text(creative.emoji!,
                              style: const TextStyle(fontSize: 64))
                          : Icon(creative.icon ?? Icons.campaign,
                              size: 64, color: accent),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      creative.headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnFelt,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      creative.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textFeltMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    GlassButton(
                      label: creative.ctaLabel,
                      onPressed: widget.onCta,
                      size: GlassButtonSize.large,
                      color: accent,
                      width: 220,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Ad attribution label (top-left).
          Positioned(
            top: topPadding + 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                creative.adLabel,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.4,
                  color: Colors.white70,
                ),
              ),
            ),
          ),

          // Close (X) affordance — appears after the delay (top-right).
          Positioned(
            top: topPadding + 12,
            right: 12,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _closable
                  ? IconButton(
                      key: const Key('house_interstitial_close'),
                      onPressed: widget.onClose,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                      ),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 22),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
