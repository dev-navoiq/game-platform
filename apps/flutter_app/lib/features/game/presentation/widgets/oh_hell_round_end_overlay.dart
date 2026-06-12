import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/utils/player_avatar.dart';
import '../../../../shared/animations/transitions/modal_transitions.dart';

/// Per-round + cumulative scoreboard shown when an Oh Hell round ends.
///
/// Each row is one player: their bid, tricks won this round, points earned
/// this round, and total session score. Optionally renders a compact
/// "history" footer with one column per completed round. For mid-game
/// round transitions a 30-sec countdown auto-fires [onContinue] so the
/// table doesn't stall on whichever human is slowest to tap. Game-end
/// path stays manual — "Play Again" is an explicit choice.
class OhHellRoundEndOverlay extends StatefulWidget {
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
  final int autoStartSeconds;
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
    this.autoStartSeconds = 30,
  });

  @override
  State<OhHellRoundEndOverlay> createState() => _OhHellRoundEndOverlayState();
}

class _OhHellRoundEndOverlayState extends State<OhHellRoundEndOverlay> {
  Timer? _tickTimer;
  int _countdown = 0;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    // No countdown at game end — the human picks Play Again or Leave.
    if (widget.isGameOver || widget.autoStartSeconds <= 0) return;
    _countdown = widget.autoStartSeconds;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown -= 1);
      if (_countdown <= 0) {
        timer.cancel();
        _fire();
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    _tickTimer?.cancel();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final localMadeBid = (widget.tricksWon[widget.localPlayerId] ?? 0) ==
        (widget.bids[widget.localPlayerId] ?? -1);

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
                Flexible(
                  child: OhHellScoreTable(
                    roundNumber: widget.roundNumber,
                    cardsThisRound: widget.cardsThisRound,
                    playerOrder: widget.playerOrder,
                    localPlayerId: widget.localPlayerId,
                    bids: widget.bids,
                    tricksWon: widget.tricksWon,
                    roundPoints: widget.roundPoints,
                    scores: widget.scores,
                    roundHistory: widget.roundHistory,
                    isGameOver: widget.isGameOver,
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

  Widget _buildContinueButton() {
    final showCountdown = !widget.isGameOver && _countdown > 0;
    final label = widget.isGameOver
        ? 'Play Again'
        : showCountdown
            ? 'Next Round (${_countdown}s)'
            : 'Next Round';
    return GestureDetector(
      onTap: _fire,
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
            label,
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

/// Score-table body for an Oh Hell round-end.
///
/// Data-only: renders the header, per-round table (one row per player with
/// bid/won/+pts/total), and the multi-round history strip. Safe to embed
/// in a bottom sheet — content is wrapped in a SingleChildScrollView.
class OhHellScoreTable extends StatelessWidget {
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

  const OhHellScoreTable({
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
    this.isGameOver = false,
  });

  @override
  Widget build(BuildContext context) {
    final emojis = PlayerAvatar.emojiMap(playerOrder);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildPerRoundTable(emojis),
          if (roundHistory.length > 1) ...[
            const SizedBox(height: 16),
            _buildHistoryStrip(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
}
