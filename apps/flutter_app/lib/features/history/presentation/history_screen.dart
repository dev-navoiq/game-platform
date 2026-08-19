import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/history_repository.dart';
import '../providers/history_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedGameType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: 'Game History',
          actions: [
            PopupMenuButton<String?>(
              icon: Icon(
                Icons.filter_list,
                color: _selectedGameType != null
                    ? AppColors.accent
                    : AppColors.textDark,
              ),
              onSelected: (value) =>
                  setState(() => _selectedGameType = value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('All Games'),
                ),
                ..._gameTypes.map((gt) => PopupMenuItem(
                      value: gt.key,
                      child: Text(gt.label),
                    )),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(
                height: MediaQuery.of(context).padding.top + 56 + 8),
            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassContainer(
                borderRadius: 12,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.accent.withOpacity(0.25),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'Recent Games'),
                    Tab(text: 'Statistics'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RecentGamesTab(gameType: _selectedGameType),
                  _StatisticsTab(gameType: _selectedGameType),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Game type filter data ─────────────────────────────────────────────────

class _GameTypeEntry {
  final String key;
  final String label;
  const _GameTypeEntry(this.key, this.label);
}

const _gameTypes = [
  _GameTypeEntry('twenty_nine', 'Twenty-Nine'),
  _GameTypeEntry('oh_hell', 'Oh Hell'),
  _GameTypeEntry('hearts', 'Hearts'),
  _GameTypeEntry('spades', 'Spades'),
  _GameTypeEntry('chess', 'Chess'),
  _GameTypeEntry('ludo', 'Ludo'),
  _GameTypeEntry('sequence', 'Sequence'),
];

String _displayNameFor(String gameType) {
  for (final gt in _gameTypes) {
    if (gt.key == gameType) return gt.label;
  }
  return gameType;
}

// ── Recent Games Tab ──────────────────────────────────────────────────────

class _RecentGamesTab extends ConsumerWidget {
  final String? gameType;
  const _RecentGamesTab({this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentGames = ref.watch(recentGamesProvider(gameType));

    return recentGames.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: Colors.white70)),
      ),
      data: (games) {
        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64,
                    color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                const Text(
                  'No games played yet',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: games.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _GameHistoryCard(game: games[index]),
        );
      },
    );
  }
}

class _GameHistoryCard extends StatelessWidget {
  final RecentGame game;
  const _GameHistoryCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      borderColor: _resultBorderColor(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: result badge + game name + date
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _resultColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  game.result.toUpperCase(),
                  style: TextStyle(
                    color: _resultColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _displayNameFor(game.gameType),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(game.playedAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _StatChip(Icons.timer, game.durationDisplay),
              const SizedBox(width: 14),
              _StatChip(Icons.stars, '${game.pointsEarned ?? 0}'),
              const SizedBox(width: 14),
              _StatChip(
                Icons.trending_up,
                game.eloChangeDisplay,
                color: (game.eloChange ?? 0) >= 0
                    ? Colors.green
                    : Colors.red,
              ),
              // Reward receipt — only games that actually paid carry it
              // (pre-2026-08-04 rows have no receipt; showing +0 there
              // would misread as "this game paid nothing").
              if ((game.coinsEarned ?? 0) > 0) ...[
                const SizedBox(width: 14),
                _StatChip(
                  Icons.monetization_on,
                  '+${game.coinsEarned}',
                  color: AppColors.accent,
                ),
              ],
              if ((game.xpEarned ?? 0) > 0) ...[
                const SizedBox(width: 14),
                _StatChip(
                  Icons.bolt,
                  '+${game.xpEarned} XP',
                  color: Colors.lightBlueAccent,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Opponents
          if (game.opponentNames.isNotEmpty)
            Text(
              'vs ${game.opponentNames.join(", ")}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),

          // Replay button
          if (game.roomId != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () =>
                  context.push(AppRoutes.replayPath(game.roomId!)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.replay, size: 16, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Watch Replay',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _resultColor() {
    switch (game.result) {
      case 'win':
        return Colors.green;
      case 'loss':
        return Colors.red;
      case 'draw':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _resultBorderColor() {
    return _resultColor().withOpacity(0.25);
  }

  static String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const _StatChip(this.icon, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ── Statistics Tab ────────────────────────────────────────────────────────

class _StatisticsTab extends ConsumerWidget {
  final String? gameType;
  const _StatisticsTab({this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(gameStatsProvider(gameType));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: Colors.white70)),
      ),
      data: (stats) {
        if (stats.totalGames == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 64,
                    color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                const Text(
                  'No stats yet — play some games!',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Win rate card
              _StatsCard(
                title: 'Win Rate',
                value: stats.winRateDisplay,
                icon: Icons.emoji_events,
                color: Colors.amber,
                subtitle:
                    '${stats.wins}W - ${stats.losses}L - ${stats.draws}D',
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _StatsCard(
                      title: 'Total Games',
                      value: '${stats.totalGames}',
                      icon: Icons.games,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsCard(
                      title: 'Points',
                      value: '${stats.totalPointsEarned}',
                      icon: Icons.stars,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _StatsCard(
                      title: 'Win Streak',
                      value: '${stats.currentWinStreak}',
                      icon: Icons.local_fire_department,
                      color: Colors.orange,
                      subtitle: 'Best: ${stats.bestWinStreak}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsCard(
                      title: 'Avg Duration',
                      value: stats.avgDurationDisplay,
                      icon: Icons.timer,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      borderColor: color.withOpacity(0.3),
      surfaceColor: color,
      surfaceOpacity: 0.08,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
