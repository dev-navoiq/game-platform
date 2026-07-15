import 'dart:ui' show Color;

import '../../routing/routes.dart';
import '../../theme/colors.dart';
import 'house_ad_creative.dart';

/// The built-in house creative catalog, rotated round-robin through the
/// banner and game-end interstitial slots when the ad mode is `house`.
///
/// Order matters: rotation serves creatives in list order and persists the
/// cursor across restarts (see `HouseAdRotation`).
const List<HouseAdCreative> kHouseAdCatalog = [
  HouseAdCreative(
    id: 'go_pro',
    headline: 'Go Pro — No Ads',
    body: 'Unlimited games, zero interruptions. Support the table.',
    ctaLabel: 'Upgrade',
    route: AppRoutes.subscription,
    accentColor: AppColors.accent,
    emoji: '👑',
  ),
  HouseAdCreative(
    id: 'practice_bots',
    headline: 'Practice vs Bots',
    body: 'Sharpen your Ludo game offline — no internet needed.',
    ctaLabel: 'Play Now',
    // Practice is launched from the lobby (practice_launcher.dart has no
    // route of its own), so deep-link to the Ludo lobby where the
    // "Practice vs Bots" button lives.
    route: '/lobby/ludo',
    accentColor: AppColors.success,
    emoji: '🤖',
  ),
  HouseAdCreative(
    id: 'season_pass',
    headline: 'Season Pass',
    body: 'New season rewards are live. Climb the track before it resets.',
    ctaLabel: 'View Pass',
    route: AppRoutes.seasonPass,
    accentColor: AppColors.accentSoft,
    emoji: '🏆',
  ),
  HouseAdCreative(
    id: 'referral',
    headline: 'Bring Your Table',
    body: 'Invite friends with your referral code and earn coins together.',
    ctaLabel: 'Invite',
    route: AppRoutes.referral,
    accentColor: AppColors.secondary,
    emoji: '🎉',
  ),
  HouseAdCreative(
    id: 'bolt_cola_demo',
    headline: 'Bolt Cola',
    body: 'Recharge between rounds. Zero sugar, full spark.',
    ctaLabel: 'Learn More',
    route: null, // Demo sponsor creative — no in-app destination.
    // Matches kBoltColaBranding.primary in ludo_sponsor_branding.dart.
    accentColor: Color(0xFFD32F2F),
    emoji: '⚡',
    adLabel: 'Sponsored · Demo',
  ),
];
