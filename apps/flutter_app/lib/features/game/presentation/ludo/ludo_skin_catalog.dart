import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/monetization_providers.dart';
import 'ludo_rider_skin.dart';
import 'ludo_sponsor_branding.dart';

/// One selectable Ludo character. [premium] skins require a tier with
/// `TierBenefits.exclusiveSkins` (Pro / Max).
class LudoSkinOption {
  final String id;
  final String name;
  final String tagline;
  final bool premium;
  final LudoRiderSkin skin;

  /// Non-null for sponsor-branded skins: the picker shows a "Sponsored" chip
  /// and the board applies the sponsor's accent while the skin is equipped.
  /// Sponsored skins are free — the sponsor pays, not the player.
  final SponsorBranding? sponsor;

  const LudoSkinOption({
    required this.id,
    required this.name,
    required this.tagline,
    required this.premium,
    required this.skin,
    this.sponsor,
  });
}

/// Every character the picker offers. First entry is the free default and the
/// fallback when a premium selection is no longer covered by the user's tier.
const kLudoSkins = <LudoSkinOption>[
  LudoSkinOption(
    id: 'scooter',
    name: 'Scooter',
    tagline: 'The original — headlight on, no rider',
    premium: false,
    skin: ScooterSkin(),
  ),
  LudoSkinOption(
    id: 'classic',
    name: 'Classic',
    tagline: 'Traditional Ludo pawns',
    premium: false,
    skin: ClassicSkin(),
  ),
  LudoSkinOption(
    id: 'rider-scooter',
    name: 'Scooter Rider',
    tagline: 'Helmeted rider who leans into corners',
    premium: true,
    skin: RiderScooterSkin(),
  ),
  LudoSkinOption(
    id: 'rider-bike',
    name: 'Superbike',
    tagline: 'Tucked racer with exhaust flames',
    premium: true,
    skin: RiderBikeSkin(),
  ),
  // ── Sponsor-branded examples (fictional brands) ──
  // Demonstrates the sponsorship seam: one SponsorBranding const + one entry
  // here is a complete "deal". Free to equip; sponsor accent shows on the
  // token (rear box livery) and the board (wash + center roundel).
  LudoSkinOption(
    id: 'sponsor-bolt-cola',
    name: 'Bolt Cola Racer',
    tagline: 'Delivery scooter, cola-red top box',
    premium: false,
    skin: SponsoredRiderSkin(
        base: RiderScooterSkin(), branding: kBoltColaBranding),
    sponsor: kBoltColaBranding,
  ),
  LudoSkinOption(
    id: 'sponsor-nimbus-airways',
    name: 'Nimbus Express',
    tagline: 'Sky-blue courier for Nimbus Airways',
    premium: false,
    skin: SponsoredRiderSkin(
        base: RiderBikeSkin(), branding: kNimbusAirwaysBranding),
    sponsor: kNimbusAirwaysBranding,
  ),
];

LudoSkinOption ludoSkinById(String id) => kLudoSkins.firstWhere(
      (s) => s.id == id,
      orElse: () => kLudoSkins.first,
    );

/// Persists the picked skin id locally — a cosmetic, per-device choice, so
/// SharedPreferences is enough (move to a `profiles` column if it should roam).
class SelectedLudoSkinNotifier extends StateNotifier<String> {
  static const _prefsKey = 'selected_ludo_skin';

  SelectedLudoSkinNotifier() : super(kLudoSkins.first.id) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && mounted) state = saved;
  }

  Future<void> select(String id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
  }
}

final selectedLudoSkinIdProvider =
    StateNotifierProvider<SelectedLudoSkinNotifier, String>(
        (ref) => SelectedLudoSkinNotifier());

/// The skin the board should actually render: the user's selection, downgraded
/// to the free default when a premium pick isn't covered by the current tier
/// (e.g. the subscription lapsed since it was chosen).
final ludoRiderSkinProvider = Provider<LudoRiderSkin>((ref) {
  final option = ludoSkinById(ref.watch(selectedLudoSkinIdProvider));
  final unlocked =
      !option.premium || ref.watch(tierBenefitsProvider).exclusiveSkins;
  return unlocked ? option.skin : kLudoSkins.first.skin;
});

/// Sponsor branding of the skin the board is actually rendering (null for
/// unsponsored skins) — mirrors [ludoRiderSkinProvider]'s downgrade logic so
/// the board accent can never outlive the skin that carried it.
final ludoSponsorBrandingProvider = Provider<SponsorBranding?>((ref) {
  final option = ludoSkinById(ref.watch(selectedLudoSkinIdProvider));
  final unlocked =
      !option.premium || ref.watch(tierBenefitsProvider).exclusiveSkins;
  return unlocked ? option.sponsor : null;
});
