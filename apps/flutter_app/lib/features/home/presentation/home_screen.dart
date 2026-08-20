import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/live_games_provider.dart';
import '../../../core/di/monetization_providers.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/currency_display.dart';
import '../../../shared/widgets/daily_challenge_card.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/friend_activity_card.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../friends/presentation/friend_activity_actions.dart';
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

/// Streams the current user's `current_activity` and exposes a
/// [ResumeRoomInfo] if there's a room worth resuming. LIVE, not one-shot:
/// when a tournament match opens a room while the player idles on the home
/// screen, the server stamps current_activity and this card must appear
/// immediately — the old single fetch missed exactly that moment (testers
/// wandered into bot practice games while their real match sat waiting).
final resumeRoomProvider =
    StreamProvider.autoDispose<ResumeRoomInfo?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  final client = ref.read(supabaseProvider);
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .map((rows) {
        if (rows.isEmpty) return null;
        final activity =
            rows.first['current_activity'] as Map<String, dynamic>?;
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
      });
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
            AppLocalizations.of(context).chooseAGame,
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
              tooltip: AppLocalizations.of(context).tournaments,
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
    final l10n = AppLocalizations.of(context);
    final infoAsync = ref.watch(resumeRoomProvider);
    final info = infoAsync.valueOrNull;
    if (info == null) return const SizedBox.shrink();

    final subtitle = switch (info.type) {
      'in_game' =>
        '${l10n.resumeInGame}${info.gameType != null ? ' • ${_friendlyGameType(l10n, info.gameType!)}' : ''}',
      'in_lobby' => l10n.resumeInLobby,
      'spectating' => l10n.resumeSpectating,
      _ => l10n.resumeTapToRejoin,
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
                    l10n.resumeGame,
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

  static String _friendlyGameType(AppLocalizations l10n, String raw) {
    return switch (raw) {
      'twenty_nine' => l10n.gameNameTwentyNine,
      'oh_hell' => l10n.gameNameOhHell,
      'hearts' => l10n.gameNameHearts,
      'spades' => l10n.gameNameSpades,
      'bridge' => l10n.gameNameBridge,
      'chess' => l10n.gameNameChess,
      'ludo' => l10n.gameNameLudo,
      'sequence' => l10n.gameNameSequence,
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
              AppLocalizations.of(context).friends,
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
                AppLocalizations.of(context).seeAll,
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
                onAction: () =>
                    handleFriendActivityAction(context, ref, friend),
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
              AppLocalizations.of(context).dailyChallenges,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnFelt,
              ),
            ),
            const Spacer(),
            Text(
              AppLocalizations.of(context).resetsIn(12),
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

/// 2-column grid of game tiles with per-game art + idle animations.
class _GameGrid extends ConsumerWidget {
  const _GameGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tiles = <(String type, String title, String subtitle)>[
      (
        'twenty_nine',
        l10n.gameNameTwentyNine,
        l10n.playerCountRange('4'),
      ),
      (
        'oh_hell',
        l10n.gameNameOhHell,
        l10n.playerCountRange('4-6'),
      ),
      (
        'hearts',
        l10n.gameNameHearts,
        l10n.playerCountRange('4'),
      ),
      (
        'spades',
        l10n.gameNameSpades,
        l10n.playerCountRange('4'),
      ),
      (
        'bridge',
        l10n.gameNameBridge,
        l10n.playerCountRange('4'),
      ),
      // Chess un-hidden: the create sheet now sizes rooms from
      // GamePlayerLimits, so a chess room opens with exactly 2 seats.
      (
        'chess',
        l10n.gameNameChess,
        l10n.playerCountRange('2'),
      ),
      (
        'ludo',
        l10n.gameNameLudo,
        l10n.playerCountRange('2-4'),
      ),
      (
        'sequence',
        l10n.gameNameSequence,
        l10n.playerCountRange('2-3'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.games,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnFelt,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final (type, title, subtitle) = tiles[index];
            // #285 launch gate: sealed games render locked and never
            // navigate — the lobby route has its own guard as backstop.
            final live = ref.watch(isGameLiveProvider(type));
            return GameTileCard.fromType(
              gameType: type,
              title: title,
              subtitle: subtitle,
              animationIndex: index,
              comingSoon: !live,
              onTap: live
                  ? () => context.push(AppRoutes.lobbyPath(type))
                  : () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content:
                          Text('$title is coming soon — stay tuned!'),
                      behavior: SnackBarBehavior.floating,
                    )),
            );
          },
        ),
      ],
    );
  }
}
