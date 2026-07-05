import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/monetization_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/currency_display.dart';
import '../../../shared/widgets/daily_challenge_card.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/friend_activity_card.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../friends/providers/friends_providers.dart';
import 'widgets/favorites_section.dart';
import 'widgets/game_tile_card.dart';

/// Active-room snapshot derived from `profiles.current_activity`. Surfaced
/// on the home screen as a "Resume Game" card so a player who forfeited
/// (their slot is bot-subbed in the room) or hit a phone restart mid-game
/// can drop back in. A null value means no resumable room — the card hides.
class ResumeRoomInfo {
  final String roomId;
  final String? roomCode;
  final String? gameType;
  // 'in_game' | 'in_lobby' | 'spectating' — from current_activity.type.
  final String type;

  const ResumeRoomInfo({
    required this.roomId,
    required this.type,
    this.roomCode,
    this.gameType,
  });
}

/// Looks up the current user's `current_activity` and exposes a
/// [ResumeRoomInfo] if there's a room worth resuming. autoDispose so the
/// home screen refetches each time it's pushed back onto.
final resumeRoomProvider =
    FutureProvider.autoDispose<ResumeRoomInfo?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final supabase = ref.read(supabaseServiceProvider);
  try {
    final profile = await supabase.getProfile();
    final activity = profile['current_activity'] as Map<String, dynamic>?;
    if (activity == null) return null;

    final type = activity['type'] as String?;
    final roomId = activity['room_id'] as String?;
    if (roomId == null || type == null) return null;
    if (!['in_game', 'in_lobby', 'spectating'].contains(type)) return null;

    return ResumeRoomInfo(
      roomId: roomId,
      type: type,
      roomCode: activity['room_code'] as String?,
      gameType: activity['game_type'] as String?,
    );
  } catch (_) {
    // Auth/network blip — hide the card rather than showing an error chip.
    // The user can pull-to-refresh once we add that, or restart the app.
    return null;
  }
});

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
            CurrencyDisplay(
              coins: ref.watch(currencyBalanceProvider).coins,
              gems: ref.watch(currencyBalanceProvider).gems,
              compact: true,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined,
                  color: AppColors.textDark),
              tooltip: 'Tournaments',
              onPressed: () => context.push(AppRoutes.tournaments),
            ),
            IconButton(
              icon: const Icon(Icons.history, color: AppColors.textDark),
              onPressed: () => context.push(AppRoutes.history),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline,
                  color: AppColors.textDark),
              onPressed: () => context.push(AppRoutes.messages),
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
            // Resume Game card (shows when current_activity points at a room).
            const _ResumeGameCard(),

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

/// Glass card that appears at the top of the home screen when the current
/// user has an in-progress room (via `profiles.current_activity`). Tapping
/// it invokes the join-room edge function in reclaim mode (clears the
/// substitute bot, flips `disconnected_at` back to null) and routes the
/// player into the room or game screen depending on its current phase.
class _ResumeGameCard extends ConsumerWidget {
  const _ResumeGameCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(resumeRoomProvider);
    final info = infoAsync.valueOrNull;
    if (info == null) return const SizedBox.shrink();

    final subtitle = switch (info.type) {
      'in_game' => 'A game is in progress${info.gameType != null ? ' • ${_friendlyGameType(info.gameType!)}' : ''}',
      'in_lobby' => 'You\'re waiting in a lobby',
      'spectating' => 'You\'re spectating a game',
      _ => 'Tap to rejoin',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        onTap: () => _resume(context, ref, info),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill,
                color: AppColors.accent, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resume Game',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    ResumeRoomInfo info,
  ) async {
    final supabase = ref.read(supabaseServiceProvider);
    // Always call join-room — server reclaims the slot if disconnected_at
    // is set (the forfeit/disconnect case), otherwise returns ALREADY_IN_ROOM
    // which we treat as a no-op (the user is still actively seated, e.g.
    // they had the app open in two places). Either way, the next step is
    // navigation.
    try {
      await supabase.joinRoom(
        roomId: info.roomId,
        asSpectator: info.type == 'spectating',
      );
    } catch (e) {
      // ALREADY_IN_ROOM, network blip, etc — log and proceed. If the room
      // is gone (abandoned), the room/game screen will surface that.
      print('[ResumeGameCard] joinRoom returned non-fatal: $e');
    }

    if (!context.mounted) return;

    // Refresh the resume card so it updates after we navigate back.
    ref.invalidate(resumeRoomProvider);

    if (info.type == 'in_game' || info.type == 'spectating') {
      context.push(AppRoutes.gamePath(info.roomId));
    } else {
      context.push(AppRoutes.roomPath(info.roomId));
    }
  }

  static String _friendlyGameType(String raw) {
    return switch (raw) {
      'twenty_nine' => '29',
      'oh_hell' => 'Oh Hell',
      'hearts' => 'Hearts',
      'spades' => 'Spades',
      'bridge' => 'Bridge',
      'chess' => 'Chess',
      'ludo' => 'Ludo',
      'sequence' => 'Sequence',
      _ => raw,
    };
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
                onAction: () => context.push(
                  AppRoutes.dmThreadPath(friend.friendId),
                ),
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
