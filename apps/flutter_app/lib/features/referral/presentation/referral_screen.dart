import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/theme/glass_tokens.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_card.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const referralCode = 'ABC123'; // TODO: Get from user profile

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Invite Friends'),
        body: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
            bottom: 40,
          ),
          children: [
            // Referral code card
            GlassCard(
              enableGlow: true,
              glowColor: AppColors.accent,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.card_giftcard, size: 48, color: AppColors.accent),
                  const SizedBox(height: 12),
                  const Text(
                    'Your Referral Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Code display
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.accent.withOpacity(0.1),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      referralCode,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlassButton(
                        label: 'Copy',
                        onPressed: () {
                          Clipboard.setData(
                              const ClipboardData(text: referralCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied!')),
                          );
                        },
                        variant: GlassButtonVariant.outlined,
                        size: GlassButtonSize.small,
                        icon: Icon(Icons.copy,
                            color: AppColors.accent, size: 16),
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        label: 'Share',
                        onPressed: () {
                          // TODO: Share via platform share sheet
                        },
                        size: GlassButtonSize.small,
                        icon: const Icon(Icons.share,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Rewards info
            GlassCard(
              title: 'Earn Rewards',
              leading: Icon(Icons.emoji_events, color: AppColors.accent),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _RewardTier(
                    icon: Icons.person_add,
                    title: 'Friend Signs Up',
                    reward: '+100 coins each',
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 10),
                  _RewardTier(
                    icon: Icons.games,
                    title: 'Friend Plays 5 Games',
                    reward: '+50 gems each',
                    color: GlassTokens.info,
                  ),
                  const SizedBox(height: 10),
                  _RewardTier(
                    icon: Icons.star,
                    title: 'Refer 5 Friends',
                    reward: 'Exclusive Card Skin',
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Referred friends list
            Text(
              'Referred Friends',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.people_outline,
                      size: 40, color: AppColors.textMuted.withOpacity(0.4)),
                  const SizedBox(height: 8),
                  Text(
                    'No referrals yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share your code to start earning rewards!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
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

class _RewardTier extends StatelessWidget {
  final IconData icon;
  final String title;
  final String reward;
  final Color color;

  const _RewardTier({
    required this.icon,
    required this.title,
    required this.reward,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                reward,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
