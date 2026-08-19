import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/theme/glass_tokens.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/leaderboard_repository.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _period = 'week';

  static const _periods = [
    ('This Week', 'week'),
    ('All Time', 'all'),
  ];

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(leaderboardProvider(_period));
    final myUserId = ref.watch(currentUserProvider)?.id;

    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Leaderboard'),
        body: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async =>
              ref.refresh(leaderboardProvider(_period).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 56 + 16,
              left: 16,
              right: 16,
              bottom: 100,
            ),
            children: [
              // Period chips
              Row(
                children: [
                  for (final (label, value) in _periods) ...[
                    GestureDetector(
                      onTap: () => setState(() => _period = value),
                      child: AnimatedContainer(
                        duration: GlassTokens.durationFast,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(GlassTokens.radiusRound),
                          color: _period == value
                              ? AppColors.accent
                              : Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: _period == value
                                ? AppColors.accent
                                : AppColors.glassBorder.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _period == value
                                ? Colors.white
                                : AppColors.textOnFelt,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              boardAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      'Couldn’t load the leaderboard.\nPull down to retry.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textFeltMuted),
                    ),
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? const _EmptyBoard()
                    : _Board(entries: entries, myUserId: myUserId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(
        child: Text(
          'No games played yet this period.\nWin games to earn XP and claim the podium!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textFeltMuted),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String? myUserId;

  const _Board({required this.entries, required this.myUserId});

  @override
  Widget build(BuildContext context) {
    final top3 = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];
    final onBoard = myUserId != null &&
        entries.any((e) => e.userId == myUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top 3 podium (2nd — 1st — 3rd)
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: top3.length > 1
                  ? _PodiumCard(
                      entry: top3[1],
                      color: const Color(0xFFC0C0C0),
                      height: 100,
                      isMe: top3[1].userId == myUserId,
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PodiumCard(
                entry: top3[0],
                color: AppColors.accent,
                height: 120,
                isMe: top3[0].userId == myUserId,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: top3.length > 2
                  ? _PodiumCard(
                      entry: top3[2],
                      color: const Color(0xFFCD7F32),
                      height: 80,
                      isMe: top3[2].userId == myUserId,
                    )
                  : const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        for (final entry in rest) ...[
          _RankedPlayerRow(entry: entry, isMe: entry.userId == myUserId),
          const SizedBox(height: 6),
        ],
        if (myUserId != null && !onBoard) ...[
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'You’re not on the board yet — keep playing!',
              style: TextStyle(color: AppColors.textFeltMuted, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final Color color;
  final double height;
  final bool isMe;

  const _PodiumCard({
    required this.entry,
    required this.color,
    required this.height,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      enableHover: false,
      child: Container(
        decoration: isMe
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent, width: 2),
              )
            : null,
        child: SizedBox(
          height: height + 60,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                ),
                child: Center(
                  child: Text(
                    entry.rank == 1
                        ? '👑'
                        : entry.rank == 2
                            ? '🥈'
                            : '🥉',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  isMe ? '${entry.username} (you)' : entry.username,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.score} XP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                height: height * 0.4,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Text(
                    '#${entry.rank}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankedPlayerRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;

  const _RankedPlayerRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      enableHover: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        decoration: isMe
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent),
              )
            : null,
        padding: isMe ? const EdgeInsets.all(4) : EdgeInsets.zero,
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#${entry.rank}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.playerColor(entry.rank - 1).withOpacity(0.15),
              ),
              child: Center(
                child: Text(
                  entry.username.isNotEmpty
                      ? entry.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.playerColor(entry.rank - 1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.username + (isMe ? ' (you)' : ''),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Lv ${entry.level} · ${entry.wins}W / ${entry.games} games',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.score} XP',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
