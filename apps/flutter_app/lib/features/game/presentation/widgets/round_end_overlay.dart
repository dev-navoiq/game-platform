import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import 'twenty_nine_scorecards.dart';

/// Overlay shown at the end of a round in Twenty-Nine.
///
/// Shows who won the round, bid vs actual points, and session scores.
/// Requires human confirmation to proceed. Optionally auto-starts
/// after [autoStartSeconds] if set (0 = no auto-start).
class RoundEndOverlay extends StatefulWidget {
  /// Which team won this round (0 or 1).
  final int winningTeam;

  /// The local player's team (0 or 1).
  final int localTeam;

  /// The bid value for this round.
  final int bid;

  /// Team that placed the bid (0 or 1).
  final int biddingTeam;

  /// Card points won by each team this round.
  final Map<int, int> teamPoints;

  /// Whether the bidding team met their bid.
  final bool bidMet;

  /// Session scores (game points, first to 6 wins).
  final Map<int, int> sessionScores;

  /// Round number that just completed.
  final int roundNumber;

  /// Seconds before auto-starting next round. 0 = manual only.
  final int autoStartSeconds;

  /// Called when user confirms to start next round.
  final VoidCallback onContinue;

  const RoundEndOverlay({
    super.key,
    required this.winningTeam,
    required this.localTeam,
    required this.bid,
    required this.biddingTeam,
    required this.teamPoints,
    required this.bidMet,
    required this.sessionScores,
    required this.roundNumber,
    this.autoStartSeconds = 0,
    required this.onContinue,
  });

  @override
  State<RoundEndOverlay> createState() => _RoundEndOverlayState();
}

class _RoundEndOverlayState extends State<RoundEndOverlay> {
  Timer? _autoTimer;
  int _countdown = 0;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartSeconds > 0) {
      _countdown = widget.autoStartSeconds;
      _autoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _countdown--);
        if (_countdown <= 0) {
          timer.cancel();
          _confirm();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _confirm() {
    if (_confirmed) return;
    _confirmed = true;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final localWon = widget.winningTeam == widget.localTeam;

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: (localWon ? Colors.green : Colors.red).withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TwentyNineScoreTable(
                winningTeam: widget.winningTeam,
                localTeam: widget.localTeam,
                bid: widget.bid,
                biddingTeam: widget.biddingTeam,
                teamPoints: widget.teamPoints,
                bidMet: widget.bidMet,
                sessionScores: widget.sessionScores,
                roundNumber: widget.roundNumber,
              ),
              const SizedBox(height: 20),

              // Continue button
              GestureDetector(
                onTap: _confirm,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _countdown > 0
                          ? 'Next Round ($_countdown)'
                          : 'Next Round',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

/// Score-table body for a Twenty-Nine round-end.
///
/// Data-only: renders the result header, bid outcome, per-team points,
/// and cumulative session scores. Safe to embed in a bottom sheet —
/// content is wrapped in a SingleChildScrollView so tall content scrolls.
class TwentyNineScoreTable extends StatelessWidget {
  final int winningTeam;
  final int localTeam;
  final int bid;
  final int biddingTeam;
  final Map<int, int> teamPoints;
  final bool bidMet;
  final Map<int, int> sessionScores;
  final int roundNumber;

  /// Optional: Royal Wedding adjustment applied to the bid threshold this
  /// round. Negative when the bidder team reduced the threshold.
  final int? bidAdjustment;

  /// Optional: per-team red/black pip totals. When supplied, the table
  /// renders the scorecards instead of the legacy "match score" row.
  final Map<int, int>? redPips;
  final Map<int, int>? blackPips;

  const TwentyNineScoreTable({
    super.key,
    required this.winningTeam,
    required this.localTeam,
    required this.bid,
    required this.biddingTeam,
    required this.teamPoints,
    required this.bidMet,
    required this.sessionScores,
    required this.roundNumber,
    this.bidAdjustment,
    this.redPips,
    this.blackPips,
  });

  @override
  Widget build(BuildContext context) {
    final localWon = winningTeam == localTeam;
    final localIsBidder = biddingTeam == localTeam;
    final bidderLabel = localIsBidder ? 'Your team' : 'Opponents';
    final bidTeamPts = teamPoints[biddingTeam] ?? 0;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            localWon ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            size: 48,
            color: localWon ? AppColors.accent : Colors.red.shade400,
          ),
          const SizedBox(height: 8),

          Text(
            localWon ? 'Round Won!' : 'Round Lost',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: localWon ? AppColors.accent : Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            'Round $roundNumber',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bidMet
                  ? Colors.green.withOpacity(0.08)
                  : Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bidMet
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$bidderLabel bid $bid',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((bidAdjustment ?? 0) != 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    (bidAdjustment ?? 0) < 0
                        ? 'Royal Wedding: target ${bid + bidAdjustment!}'
                        : 'Royal Wedding: target ${bid + bidAdjustment!}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  bidMet
                      ? 'Made it with $bidTeamPts points!'
                      : 'Fell short with $bidTeamPts points',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: bidMet ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _teamColumn('Your Team', teamPoints[localTeam] ?? 0, true),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _teamColumn('Opponents', teamPoints[localTeam == 0 ? 1 : 0] ?? 0, false),
            ],
          ),
          const SizedBox(height: 16),

          if (redPips != null && blackPips != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  TwentyNineScorecards(
                    redPips: redPips!,
                    blackPips: blackPips!,
                    localTeam: localTeam,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Red 6 = wins · Black 6 = losses · first to 6 either side',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Match Score:  ',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                  Text(
                    '${sessionScores[localTeam] ?? 0}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  Text('  -  ',
                      style:
                          GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
                  Text(
                    '${sessionScores[localTeam == 0 ? 1 : 0] ?? 0}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade400,
                    ),
                  ),
                  Text('  (first to 6)',
                      style:
                          GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamColumn(String label, int points, bool isLocal) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          '$points pts',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isLocal ? AppColors.accent : Colors.red.shade400,
          ),
        ),
      ],
    );
  }
}
