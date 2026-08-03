import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/monetization_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/currency_display.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/under_construction_banner.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: 'Profile',
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: AppColors.textDark),
              onPressed: () => context.push(AppRoutes.settings),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
            bottom: 100,
          ),
          children: [
            const UnderConstructionBanner(
              message:
                  'Profile is under construction — name, level, XP and stats below are placeholders.',
            ),
            // Avatar + Name card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.15),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.5),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Guest Player',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Level badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.accent.withOpacity(0.15),
                    ),
                    child: const Text(
                      'Level 1',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // XP bar
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '0 / 100 XP',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            'Next: Level 2',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: 0,
                            backgroundColor: Color(0x26000000),
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Currency
                  CurrencyDisplay(
                    coins: ref.watch(currencyBalanceProvider).coins,
                    gems: ref.watch(currencyBalanceProvider).gems,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Subscription tier
            GlassCard(
              title: 'Subscription',
              leading: Icon(Icons.star, color: AppColors.textMuted),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.textMuted.withOpacity(0.15),
                    ),
                    child: const Text(
                      'Free Tier',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.shop),
                    child: Text(
                      'Upgrade',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats
            GlassCard(
              title: 'Statistics',
              leading:
                  Icon(Icons.bar_chart, color: AppColors.textMuted),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow('Games Played', '0'),
                  _StatRow('Win Rate', '0%'),
                  _StatRow('Best Streak', '0'),
                  _StatRow('Total Coins Earned', '0'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick links
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _QuickLink(
                    icon: Icons.emoji_events,
                    label: 'Challenges',
                    onTap: () => context.push(AppRoutes.challenges),
                  ),
                  _QuickLink(
                    icon: Icons.military_tech,
                    label: 'Season Pass',
                    onTap: () => context.push(AppRoutes.seasonPass),
                  ),
                  _QuickLink(
                    icon: Icons.card_giftcard,
                    label: 'Referral Program',
                    onTap: () => context.push(AppRoutes.referral),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
