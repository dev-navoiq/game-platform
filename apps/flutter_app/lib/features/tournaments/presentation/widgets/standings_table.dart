import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../data/tournament_models.dart';

/// Displays standings for round robin / swiss tournaments.
class StandingsTable extends StatelessWidget {
  final List<TournamentParticipant> participants;
  final String? currentUserId;

  const StandingsTable({
    super.key,
    required this.participants,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by points desc, then game wins, then buchholz
    final sorted = List<TournamentParticipant>.from(participants)
      ..sort((a, b) {
        final pointsDiff = b.points.compareTo(a.points);
        if (pointsDiff != 0) return pointsDiff;
        final gwDiff = b.gameWins.compareTo(a.gameWins);
        if (gwDiff != 0) return gwDiff;
        return b.buchholz.compareTo(a.buchholz);
      });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(GlassTokens.radiusMedium),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 28, child: Text('#', style: _headerStyle)),
                Expanded(child: Text('Player', style: _headerStyle)),
                SizedBox(
                    width: 32,
                    child: Text('W', style: _headerStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 32,
                    child: Text('L', style: _headerStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 32,
                    child: Text('D', style: _headerStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 36,
                    child: Text('Pts', style: _headerStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Rows
          ...sorted.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final p = entry.value;
            final isMe = p.userId == currentUserId;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.accent.withOpacity(0.1)
                    : (rank.isOdd
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.03)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank <= 3
                            ? AppColors.accent
                            : AppColors.textOnFelt,
                        fontWeight: rank <= 3
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      p.username ?? 'Player',
                      style: TextStyle(
                        color: AppColors.textOnFelt,
                        fontWeight:
                            isMe ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('${p.wins}',
                        style: _cellStyle, textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('${p.losses}',
                        style: _cellStyle, textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('${p.draws}',
                        style: _cellStyle, textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${p.points}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    color: AppColors.textFeltMuted,
    fontWeight: FontWeight.w600,
    fontSize: 11,
  );

  static const _cellStyle = TextStyle(
    color: AppColors.textOnFelt,
    fontSize: 13,
  );
}
