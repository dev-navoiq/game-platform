import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../data/tournament_models.dart';

class TournamentCard extends StatefulWidget {
  final Tournament tournament;
  final VoidCallback? onTap;

  /// Optional outcome line for history contexts (My Tournaments): placement
  /// and net coins/gems for the viewing user (#187).
  final String? outcomeText;
  final Color? outcomeColor;

  const TournamentCard({
    super.key,
    required this.tournament,
    this.onTap,
    this.outcomeText,
    this.outcomeColor,
  });

  @override
  State<TournamentCard> createState() => _TournamentCardState();
}

class _TournamentCardState extends State<TournamentCard> {
  Tournament get tournament => widget.tournament;
  String? get outcomeText => widget.outcomeText;
  Color? get outcomeColor => widget.outcomeColor;

  /// Countdown re-render (#259): realtime only rebuilds cards when DATA
  /// changes, so "in 8m" used to freeze until an event arrived. Tick every
  /// 30s while a start is pending; upcoming-within-the-hour ticks read as
  /// live to the user without meaningful cost.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (tournament.status == TournamentStatus.registration ||
        tournament.status == TournamentStatus.starting) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: GlassContainer(
        borderRadius: GlassTokens.radiusMedium,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                if (tournament.isOfficial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OFFICIAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (tournament.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    tournament.name,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Game type and format chips
            Row(
              children: [
                _InfoChip(
                  icon: Icons.games_outlined,
                  label: _gameDisplayName(tournament.gameType),
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.account_tree_outlined,
                  label: tournament.format.displayName,
                ),
              ],
            ),

            // Outcome line (history contexts only): how MY run went.
            if (outcomeText != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.emoji_events_outlined,
                    label: outcomeText!,
                    color: outcomeColor,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Participants, live countdown, and status texture (#259)
            Row(
              children: [
                Icon(Icons.people_outline,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${tournament.currentParticipants}/${tournament.maxParticipants}',
                  style: TextStyle(
                    color: tournament.isFull &&
                            tournament.status == TournamentStatus.registration
                        ? AppColors.accent
                        : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: tournament.isFull ? FontWeight.w700 : null,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  _formatStartTime(tournament.startTime),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (_statusText != null)
                  _InfoChip(
                    icon: Icons.info_outline,
                    label: _statusText!,
                    color: AppColors.accent,
                  ),
              ],
            ),

            // Player-funded pool projection — grows live as entries land.
            if (tournament.playerFundedPool != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.savings_outlined,
                      color: AppColors.accent, size: 15),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pool ${tournament.playerFundedPool!.pool} coins · '
                      '🥇${tournament.playerFundedPool!.first} '
                      '🥈${tournament.playerFundedPool!.second} '
                      '🥉${tournament.playerFundedPool!.third}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Entry fee and first prize
            Row(
              children: [
                if (tournament.isFree)
                  const _InfoChip(
                    icon: Icons.check_circle_outline,
                    label: 'FREE',
                    color: AppColors.success,
                  )
                else ...[
                  if (tournament.entryFeeCoins > 0)
                    _InfoChip(
                      icon: Icons.toll,
                      label: '${tournament.entryFeeCoins} coins',
                      color: AppColors.accent,
                    ),
                  if (tournament.entryFeeGems > 0) ...[
                    const SizedBox(width: 6),
                    _InfoChip(
                      icon: Icons.diamond_outlined,
                      label: '${tournament.entryFeeGems} gems',
                      color: Colors.purple,
                    ),
                  ],
                ],
                const Spacer(),
                if (tournament.prizes.isNotEmpty) ...[
                  const Icon(Icons.emoji_events,
                      color: AppColors.accent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatPrize(tournament.prizes.first),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Status texture beyond the LIVE badge: what's happening RIGHT NOW for
  /// an upcoming event ("Full — starts 21:00", "Check-in open").
  String? get _statusText {
    if (tournament.status != TournamentStatus.registration) return null;
    if (tournament.isCheckInOpen) return 'Check-in open';
    if (tournament.isFull) {
      final local = tournament.startTime.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return 'Full — starts $hh:$mm';
    }
    return null;
  }

  String _formatStartTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);

    if (diff.isNegative) return 'Started';
    if (diff.inDays > 0) return 'in ${diff.inDays}d';
    if (diff.inHours > 0) {
      return 'in ${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    if (diff.inMinutes > 0) return 'in ${diff.inMinutes}m';
    return 'Starting soon';
  }

  String _formatPrize(TournamentPrize prize) {
    final parts = <String>[];
    if (prize.coins > 0) parts.add('${prize.coins} coins');
    if (prize.gems > 0) parts.add('${prize.gems} gems');
    if (parts.isEmpty && prize.skinId != null) return 'Skin';
    return parts.join(' + ');
  }

  static String _gameDisplayName(String gameType) {
    switch (gameType) {
      case 'twenty_nine':
        return 'Twenty-Nine';
      case 'oh_hell':
        return 'Oh Hell';
      case 'hearts':
        return 'Hearts';
      case 'spades':
        return 'Spades';
      case 'bridge':
        return 'Bridge';
      case 'rummy':
        return 'Rummy';
      case 'chess':
        return 'Chess';
      case 'ludo':
        return 'Ludo';
      case 'sequence':
        return 'Sequence';
      default:
        return gameType;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: chipColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
