import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/theme/glass_tokens.dart';
import '../../../shared/widgets/felt_background.dart';
import '../../../shared/widgets/glass_app_bar.dart';
import '../../../shared/widgets/glass_card.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _selectedGame = 'all';

  final _gameFilters = const [
    ('All', 'all'),
    ('29', 'twenty_nine'),
    ('Oh Hell', 'oh_hell'),
    ('Hearts', 'hearts'),
    ('Chess', 'chess'),
    ('Ludo', 'ludo'),
  ];

  @override
  Widget build(BuildContext context) {
    return FeltBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Leaderboard'),
        body: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 56 + 16,
            left: 16,
            right: 16,
            bottom: 100,
          ),
          children: [
            // Game filter chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _gameFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final (label, value) = _gameFilters[index];
                  final isSelected = _selectedGame == value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGame = value),
                    child: AnimatedContainer(
                      duration: GlassTokens.durationFast,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(GlassTokens.radiusRound),
                        color: isSelected
                            ? AppColors.accent
                            : Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.glassBorder.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textOnFelt,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Top 3 podium
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd place
                Expanded(
                  child: _PodiumCard(
                    rank: 2,
                    name: 'CardShark',
                    score: 2850,
                    color: const Color(0xFFC0C0C0),
                    height: 100,
                  ),
                ),
                const SizedBox(width: 8),
                // 1st place
                Expanded(
                  child: _PodiumCard(
                    rank: 1,
                    name: 'ProGamer',
                    score: 3200,
                    color: AppColors.accent,
                    height: 120,
                  ),
                ),
                const SizedBox(width: 8),
                // 3rd place
                Expanded(
                  child: _PodiumCard(
                    rank: 3,
                    name: 'ChessKing',
                    score: 2600,
                    color: const Color(0xFFCD7F32),
                    height: 80,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ranked list
            for (var i = 4; i <= 10; i++) ...[
              _RankedPlayerRow(
                rank: i,
                name: 'Player$i',
                score: 3200 - (i * 200),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final Color color;
  final double height;

  const _PodiumCard({
    required this.rank,
    required this.name,
    required this.score,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      enableHover: false,
      child: SizedBox(
        height: height + 60,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Crown / medal
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
              ),
              child: Center(
                child: Text(
                  rank == 1
                      ? '👑'
                      : rank == 2
                          ? '🥈'
                          : '🥉',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$score pts',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            // Podium base
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
                  '#$rank',
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
    );
  }
}

class _RankedPlayerRow extends StatelessWidget {
  final int rank;
  final String name;
  final int score;

  const _RankedPlayerRow({
    required this.rank,
    required this.name,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      enableHover: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar placeholder
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.playerColor(rank - 1).withOpacity(0.15),
            ),
            child: Center(
              child: Text(
                name[0],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.playerColor(rank - 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            '$score pts',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
