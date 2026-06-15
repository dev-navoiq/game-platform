import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/season_pass_progress_bar.dart';
import '../../../shared/widgets/under_construction_banner.dart';
import 'widgets/reward_node.dart';

class SeasonPassScreen extends ConsumerWidget {
  const SeasonPassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Season Pass'),
        body: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
            bottom: 40,
          ),
          children: [
            const UnderConstructionBanner(
              message:
                  'Season Pass is under construction — XP, rewards and the Premium purchase below are placeholders.',
            ),
            // Season info
            const SeasonPassProgressBar(
              currentLevel: 3,
              currentXp: 150,
              xpToNextLevel: 400,
              isPremium: false,
              maxLevel: 50,
            ),
            const SizedBox(height: 16),

            // Buy Premium Pass
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.25),
                    AppColors.accent.withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Premium Pass',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock exclusive rewards',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GlassButton(
                    label: '500 Gems',
                    onPressed: () {
                      // TODO: Purchase premium pass
                    },
                    icon: const Icon(Icons.diamond, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Free track
            Text(
              'Free Track',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final level = index + 1;
                  return RewardNode(
                    level: level,
                    label: _freeRewardLabel(level),
                    coins: _freeRewardCoins(level),
                    gems: level % 5 == 0 ? 10 : null,
                    isUnlocked: level <= 3,
                    isCurrent: level == 3,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Premium track
            Text(
              'Premium Track',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Requires Premium Pass',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textFeltMuted,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 155,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final level = index + 1;
                  return RewardNode(
                    level: level,
                    label: _premiumRewardLabel(level),
                    coins: level * 50,
                    gems: level % 3 == 0 ? 25 : null,
                    isPremium: true,
                    isUnlocked: false,
                    isCurrent: false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _freeRewardLabel(int level) {
    switch (level) {
      case 1:
        return '50 Coins';
      case 2:
        return '75 Coins';
      case 3:
        return '100 Coins';
      case 5:
        return 'Card Skin';
      case 10:
        return 'Avatar Frame';
      default:
        return '${level * 25} Coins';
    }
  }

  int _freeRewardCoins(int level) {
    switch (level) {
      case 1:
        return 50;
      case 2:
        return 75;
      case 3:
        return 100;
      default:
        return level * 25;
    }
  }

  String _premiumRewardLabel(int level) {
    switch (level) {
      case 1:
        return 'Exclusive Skin';
      case 3:
        return 'Room Theme';
      case 5:
        return 'Epic Skin';
      case 7:
        return 'Emote Pack';
      case 10:
        return 'Legendary Skin';
      default:
        return 'Bonus Coins';
    }
  }
}
