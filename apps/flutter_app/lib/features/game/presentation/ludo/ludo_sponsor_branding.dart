import 'package:flutter/material.dart';

import 'ludo_rider_skin.dart';

/// Branding for a sponsor-provided cosmetic — the whole "deal" in one value.
///
/// A real sponsorship plugs in by adding one `SponsorBranding` const plus a
/// catalog entry that carries it (see `kLudoSkins`); no engine, geometry or
/// driver changes. Everything is drawn (no image assets), consistent with the
/// vector skins — a future logo would be another drawn glyph or a Rive asset
/// behind the same seam.
@immutable
class SponsorBranding {
  /// Full display name, e.g. shown as "Sponsored by Bolt Cola".
  final String sponsorName;

  /// Short wordmark drawn on decals / the board roundel. Keep it ≤ 8 chars so
  /// it fits a board cell — it is a stand-in for a real logo.
  final String badgeText;

  /// Primary brand color (livery fill, board wash).
  final Color primary;

  /// Secondary brand color (trim, stripes, badge text).
  final Color secondary;

  const SponsorBranding({
    required this.sponsorName,
    required this.badgeText,
    required this.primary,
    required this.secondary,
  });
}

// ── Example sponsors (fictional brands only) ────────────────────────────────

/// "Bolt Cola" — red/white energy-drink look.
const kBoltColaBranding = SponsorBranding(
  sponsorName: 'Bolt Cola',
  badgeText: 'BOLT',
  primary: Color(0xFFD32F2F),
  secondary: Color(0xFFF5F5F5),
);

/// "Nimbus Airways" — sky blue/silver airline look.
const kNimbusAirwaysBranding = SponsorBranding(
  sponsorName: 'Nimbus Airways',
  badgeText: 'NIMBUS',
  primary: Color(0xFF4FC3F7),
  secondary: Color(0xFFE0E4EA),
);

/// Wraps any [LudoRiderSkin] with a sponsor livery: the base character paints
/// unchanged (player color stays legible for gameplay), then a brand-colored
/// "top box" decal is drawn over the rear wheel — outside the base silhouette
/// so it composes with every existing skin without touching their painters.
class SponsoredRiderSkin implements LudoRiderSkin {
  final LudoRiderSkin base;
  final SponsorBranding branding;

  const SponsoredRiderSkin({required this.base, required this.branding});

  @override
  void paint(Canvas canvas, RiderFrame f) {
    base.paint(canvas, f);
    _paintDecal(canvas, f);
  }

  void _paintDecal(Canvas canvas, RiderFrame f) {
    canvas.save();
    canvas.translate(f.center.dx, f.center.dy);
    // Match the base skins' cornering yaw so the box tracks the vehicle.
    canvas.rotate(f.angle + f.lean * 0.25);
    canvas.scale(f.scale);

    final u = f.sizePx * 0.82;
    final a = f.alpha;

    // Rear top box (top-down view: a rounded square over the rear wheel).
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, u * 0.42), width: u * 0.34, height: u * 0.28),
      Radius.circular(u * 0.08),
    );
    canvas.drawRRect(box, Paint()..color = branding.primary.withValues(alpha: a));
    canvas.drawRRect(
      box,
      Paint()
        ..color = branding.secondary.withValues(alpha: 0.9 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.03,
    );
    // Roundel logo mark — the drawn stand-in for the sponsor's glyph.
    canvas.drawCircle(Offset(0, u * 0.42), u * 0.08,
        Paint()..color = branding.secondary.withValues(alpha: a));
    canvas.drawCircle(Offset(0, u * 0.42), u * 0.04,
        Paint()..color = branding.primary.withValues(alpha: a));

    canvas.restore();
  }
}
