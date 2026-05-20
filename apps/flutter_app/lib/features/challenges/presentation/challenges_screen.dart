import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/daily_challenge_card.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Challenges'),
        body: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
            bottom: 40,
          ),
          children: [
            // Countdown header
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, size: 16, color: AppColors.textOnFelt),
                    const SizedBox(width: 6),
                    Text(
                      'New challenges in 12h 34m',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textOnFelt,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Daily Challenges
            Text(
              'Daily Challenges',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnFelt,
              ),
            ),
            const SizedBox(height: 12),
            DailyChallengeCard(
              title: 'Win 3 games of any type',
              current: 1,
              target: 3,
              rewardCoins: 50,
              onReroll: () {},
              rerollCost: 25,
            ),
            const SizedBox(height: 8),
            DailyChallengeCard(
              title: 'Play 5 rounds of cards',
              current: 2,
              target: 5,
              rewardCoins: 30,
              rewardGems: 5,
              onReroll: () {},
              rerollCost: 25,
            ),
            const SizedBox(height: 8),
            DailyChallengeCard(
              title: 'Score 100 total points',
              current: 45,
              target: 100,
              rewardCoins: 40,
              onReroll: () {},
              rerollCost: 25,
            ),
            const SizedBox(height: 24),

            // Weekly Challenges
            Text(
              'Weekly Challenges',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnFelt,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Resets every Monday',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textFeltMuted,
              ),
            ),
            const SizedBox(height: 12),
            DailyChallengeCard(
              title: 'Win 15 games this week',
              current: 3,
              target: 15,
              rewardCoins: 200,
              rewardGems: 25,
            ),
            const SizedBox(height: 8),
            DailyChallengeCard(
              title: 'Play 3 different game types',
              current: 1,
              target: 3,
              rewardCoins: 100,
              rewardGems: 15,
            ),
            const SizedBox(height: 8),
            DailyChallengeCard(
              title: 'Invite a friend to play',
              current: 0,
              target: 1,
              rewardCoins: 75,
              rewardGems: 10,
            ),
            const SizedBox(height: 8),
            DailyChallengeCard(
              title: 'Win 5 games in a row',
              current: 0,
              target: 5,
              rewardCoins: 150,
              rewardGems: 30,
            ),
            const SizedBox(height: 8),
            DailyChallengeCard(
              title: 'Complete all daily challenges 3 days',
              current: 0,
              target: 3,
              rewardCoins: 300,
              rewardGems: 50,
            ),
          ],
        ),
      ),
    );
  }
}
