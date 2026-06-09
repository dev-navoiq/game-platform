import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/player_avatar.dart';
import '../../../../shared/animations/transitions/modal_transitions.dart';

/// Per-round + cumulative scoreboard shown when an Oh Hell round ends.
///
/// Each row is one player: their bid, tricks won this round, points earned
/// this round, and total session score. Optionally renders a compact
/// "history" footer with one column per completed round.
class OhHellRoundEndOverlay extends StatelessWidget {
  final int roundNumber;
  final int cardsThisRound;
  final List<String> playerOrder;
  final String localPlayerId;
  final Map<String, int> bids;
  final Map<String, int> tricksWon;
  final Map<String, int> roundPoints;
  final Map<String, int> scores;
  final List<Map<String, int>> roundHistory;
  final bool isGameOver;
  final VoidCallback onContinue;

  const OhHellRoundEndOverlay({
    super.key,
    required this.roundNumber,
    required this.cardsThisRound,
    required this.playerOrder,
    required this.localPlayerId,
    required this.bids,
    required this.tricksWon,
    required this.roundPoints,
    required this.scores,
    required this.roundHistory,
    required this.onContinue,
    this.isGameOver = false,
  });

  @override
  Widget build(BuildContext context) {
    final emojis = PlayerAvatar.emojiMap(playerOrder);
    final localMadeBid = (tricksWon[localPlayerId] ?? 0) ==
        (bids[localPlayerId] ?? -1);

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: ModalEntryTransition(
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxHeight: 560),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: (localMadeBid ? AppColors.success : AppColors.danger)
                      .withOpacity(0.25),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(localMadeBid),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPerRoundTable(emojis),
                        if (roundHistory.length > 1) ...[
                          const SizedBox(height: 16),
                          _buildHistoryStrip(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool localMadeBid) {
    final title = isGameOver
        ? 'Game Over'
        : 'Round $roundNumber';
    final subtitle = isGameOver
        ? 'Final standings'
        : '$cardsThisRound card${cardsThisRound == 1 ? '' : 's'} dealt';
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildPerRoundTable(Map<String, String> emojis) {
    final headerStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.4,
    );
    final cellStyle = GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 38, child: Text('', style: headerStyle)),
              Expanded(child: Text('PLAYER', style: headerStyle)),
              SizedBox(width: 38, child: Text('BID', style: headerStyle, textAlign: TextAlign.center)),
              SizedBox(width: 38, child: Text('WON', style: headerStyle, textAlign: TextAlign.center)),
              SizedBox(width: 44, child: Text('+PTS', style: headerStyle, textAlign: TextAlign.right)),
              SizedBox(width: 50, child: Text('TOTAL', style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
          const SizedBox(height: 6),
          for (final pid in playerOrder) ...[
            _buildPlayerRow(pid, emojis, cellStyle),
            if (pid != playerOrder.last)
              Divider(
                height: 8,
                thickness: 0.5,
                color: AppColors.textMuted.withOpacity(0.15),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerRow(
    String pid,
    Map<String, String> emojis,
    TextStyle cellStyle,
  ) {
    final bid = bids[pid] ?? 0;
    final won = tricksWon[pid] ?? 0;
    final pts = roundPoints[pid] ?? 0;
    final total = scores[pid] ?? 0;
    final madeBid = won == bid;
    final isLocal = pid == localPlayerId;
    final name = PlayerAvatar.nameFor(
      playerId: pid,
      localPlayerId: localPlayerId,
      seatIndex: playerOrder.indexOf(pid),
    );
    final ptsColor = madeBid ? AppColors.success : AppColors.danger;

    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(
            emojis[pid] ?? '🎮',
            style: const TextStyle(fontSize: 22),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            name.length > 12 ? '${name.substring(0, 11)}…' : name,
            style: cellStyle.copyWith(
              color: isLocal ? AppColors.accent : AppColors.textDark,
              fontWeight: isLocal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 38, child: Text('$bid', style: cellStyle, textAlign: TextAlign.center)),
        SizedBox(width: 38, child: Text('$won', style: cellStyle, textAlign: TextAlign.center)),
        SizedBox(
          width: 44,
          child: Text(
            pts > 0 ? '+$pts' : '0',
            style: cellStyle.copyWith(color: ptsColor),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            '$total',
            style: cellStyle.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryStrip() {
    final cellStyle = GoogleFonts.inter(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
    );
    final headerStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.4,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.textMuted.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HISTORY', style: headerStyle),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('R', style: headerStyle),
                    for (final pid in playerOrder)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          (PlayerAvatar.nameFor(
                            playerId: pid,
                            localPlayerId: localPlayerId,
                            seatIndex: playerOrder.indexOf(pid),
                          ))
                              .split(' ')
                              .first,
                          style: cellStyle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                for (var i = 0; i < roundHistory.length; i++) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('${i + 1}', style: headerStyle),
                      for (final pid in playerOrder)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 24,
                            child: Text(
                              '${roundHistory[i][pid] ?? 0}',
                              style: cellStyle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: onContinue,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            isGameOver ? 'Play Again' : 'Next Round',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
