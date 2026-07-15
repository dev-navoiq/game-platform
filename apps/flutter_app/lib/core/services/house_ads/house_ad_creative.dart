import 'package:flutter/widgets.dart';

/// A single in-house ad creative, drawn natively in the "Refined Crystal"
/// style and served through the same banner/interstitial slots the AdMob
/// integration uses (when the ad mode is [AdMode.house]).
///
/// Creatives are pure data: the banner and interstitial widgets decide how
/// to render them, and the tap target is a GoRouter [route] (or nothing,
/// for demo sponsor creatives that have no in-app destination).
@immutable
class HouseAdCreative {
  /// Stable identifier (used for rotation bookkeeping and tests).
  final String id;

  /// Short headline, e.g. "Go Pro — No Ads".
  final String headline;

  /// One-line supporting copy shown on the interstitial (and, truncated,
  /// on the banner).
  final String body;

  /// Call-to-action label, e.g. "Upgrade".
  final String ctaLabel;

  /// GoRouter route the CTA/tap navigates to. `null` = no destination
  /// (e.g. the sponsor demo creative).
  final String? route;

  /// Accent colour used for glows/CTA tinting. Defaults to the Gathr gold
  /// in the catalog; sponsor creatives bring their own brand colour.
  final Color accentColor;

  /// Emoji rendered as the creative's "art" (kept native — no image assets).
  final String? emoji;

  /// Optional icon alternative to [emoji].
  final IconData? icon;

  /// Attribution label. `"Ad · Gathr"` for our own creatives; sponsor demos
  /// override it (e.g. `"Sponsored · Demo"`).
  final String adLabel;

  const HouseAdCreative({
    required this.id,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.accentColor,
    this.route,
    this.emoji,
    this.icon,
    this.adLabel = 'Ad · Gathr',
  });
}
