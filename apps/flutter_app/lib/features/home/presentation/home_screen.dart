import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/currency_display.dart';
import '../../../shared/widgets/daily_challenge_card.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/friend_activity_card.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../friends/providers/friends_providers.dart';
import 'widgets/favorites_section.dart';
import 'widgets/game_tile_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          titleWidget: Text(
            'Choose a Game',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          actions: [
            const CurrencyDisplay(coins: 200, gems: 0, compact: true),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.history, color: AppColors.textDark),
              onPressed: () => context.push(AppRoutes.history),
            ),
            IconButton(
              icon: const Icon(Icons.people_outline, color: AppColors.textDark),
              onPressed: () => context.push(AppRoutes.friends),
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
            // Friends Activity strip
            const _FriendsActivityStrip(),

            // Favorites & Recently Played
            const FavoritesSection(),

            // Daily Challenges section
            const _DailyChallengesSection(),

            // Game grid
            const _GameGrid(),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable strip showing friends' current activity.
class _FriendsActivityStrip extends ConsumerWidget {
  const _FriendsActivityStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(friendActivitiesProvider);
    final activities = activitiesAsync.valueOrNull ?? [];

    if (activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Friends',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push(AppRoutes.friends),
              child: Text(
                'See All',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final friend = activities[index];
              return FriendActivityCard(
                displayName: friend.displayName,
                avatarUrl: friend.avatarUrl,
                status: friend.status.toWidgetStatus(),
                gameType: friend.gameType,
                statusDetail: friend.statusDetail,
                roomId: friend.roomId,
                onAction: () {
                  // TODO: Navigate to room or send invite
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Daily challenges section with horizontal scroll.
class _DailyChallengesSection extends StatelessWidget {
  const _DailyChallengesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Daily Challenges',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const Spacer(),
            Text(
              'Resets in 12h',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textFeltMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              SizedBox(
                width: 200,
                child: DailyChallengeCard(
                  title: 'Win 3 games',
                  current: 0,
                  target: 3,
                  rewardCoins: 50,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: DailyChallengeCard(
                  title: 'Play 5 rounds',
                  current: 0,
                  target: 5,
                  rewardCoins: 30,
                  rewardGems: 5,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: DailyChallengeCard(
                  title: 'Score 100 points',
                  current: 0,
                  target: 100,
                  rewardCoins: 40,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// 2-column grid of game tiles.
class _GameGrid extends StatelessWidget {
  const _GameGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Games',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnFelt,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            GameTileCard(
              title: 'Twenty-Nine',
              subtitle: '4 players',
              icon: Icons.style,
              onTap: () => context.push(AppRoutes.lobbyPath('twenty_nine')),
            ),
            GameTileCard(
              title: 'Oh Hell',
              subtitle: '3-7 players',
              icon: Icons.whatshot,
              iconColor: AppColors.danger,
              onTap: () => context.push(AppRoutes.lobbyPath('oh_hell')),
            ),
            GameTileCard(
              title: 'Hearts',
              subtitle: '4 players',
              icon: Icons.favorite,
              iconColor: AppColors.cardRed,
              onTap: () => context.push(AppRoutes.lobbyPath('hearts')),
            ),
            GameTileCard(
              title: 'Spades',
              subtitle: '4 players',
              icon: Icons.eco,
              iconColor: AppColors.cardBlack,
              onTap: () => context.push(AppRoutes.lobbyPath('spades')),
            ),
            GameTileCard(
              title: 'Bridge',
              subtitle: '4 players',
              icon: Icons.dashboard,
              iconColor: AppColors.accent,
              onTap: () => context.push(AppRoutes.lobbyPath('bridge')),
            ),
            // Chess hidden until M4 (create-room form) ships — the beta's
            // hardcoded max_players=4 would leave a 2-player game in a
            // 4-seat room stuck in 'waiting'. See memory/multiplayer-room-flow-debt.
            // GameTileCard(
            //   title: 'Chess',
            //   subtitle: '2 players',
            //   icon: Icons.castle,
            //   iconColor: AppColors.primaryDark,
            //   onTap: () => context.push(AppRoutes.lobbyPath('chess')),
            // ),
            GameTileCard(
              title: 'Ludo',
              subtitle: '2-4 players',
              icon: Icons.grid_view,
              iconColor: AppColors.player3,
              onTap: () => context.push(AppRoutes.lobbyPath('ludo')),
            ),
            GameTileCard(
              title: 'Sequence',
              subtitle: '2-4 players',
              icon: Icons.apps,
              iconColor: AppColors.secondary,
              onTap: () => context.push(AppRoutes.lobbyPath('sequence')),
            ),
          ],
        ),
      ],
    );
  }
}
