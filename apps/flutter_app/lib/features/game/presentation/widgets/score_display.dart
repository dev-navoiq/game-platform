import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Glass HUD score display overlay.
class ScoreDisplay extends StatelessWidget {
  final Map<String, int> scores;
  final List<String> playerNames;
  final String? localPlayerId;

  const ScoreDisplay({
    super.key,
    required this.scores,
    this.playerNames = const [],
    this.localPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      key: const Key('score-display'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Score: ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          if (localPlayerId != null && scores.containsKey(localPlayerId))
            Text(
              '${scores[localPlayerId]}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            )
          else
            ...scores.entries.take(4).map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${e.value}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Team-based score display for Twenty-Nine and Spades.
class TeamScoreDisplay extends StatelessWidget {
  final int team0Score;
  final int team1Score;
  final int? localTeam;

  const TeamScoreDisplay({
    super.key,
    required this.team0Score,
    required this.team1Score,
    this.localTeam,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      key: const Key('score-display'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _teamLabel('Us', team0Score, localTeam == 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '|',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _teamLabel('Them', team1Score, localTeam == 1),
        ],
      ),
    );
  }

  Widget _teamLabel(String label, int score, bool isLocal) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Text(
          '$score',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isLocal ? AppColors.accent : AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
