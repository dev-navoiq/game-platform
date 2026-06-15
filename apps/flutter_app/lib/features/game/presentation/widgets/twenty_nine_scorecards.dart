import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

/// Two-team scoreboard rendered as the traditional 29 scorecards: each team
/// has a red 6 (wins / positive pips) and a black 6 (losses / negative
/// pips). The card "fills" as pips accumulate — six pips visible means
/// game over.
///
/// All four scorecards stay on-screen at all times so players can see
/// both their progress and how close their opponents are to closing out.
class TwentyNineScorecards extends StatelessWidget {
  /// Maps team-index (0/1) → red pip count (0–6).
  final Map<int, int> redPips;

  /// Maps team-index (0/1) → black pip count (0–6).
  final Map<int, int> blackPips;

  /// Which team the local player is on.
  final int localTeam;

  /// Maximum pip value before win/loss triggers. Default 6 matches
  /// `TwentyNineConfig.scorecardMax`.
  final int max;

  const TwentyNineScorecards({
    super.key,
    required this.redPips,
    required this.blackPips,
    required this.localTeam,
    this.max = 6,
  });

  @override
  Widget build(BuildContext context) {
    final otherTeam = localTeam == 0 ? 1 : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TeamScorecards(
            label: 'Us',
            isLocal: true,
            red: (redPips[localTeam] ?? 0).clamp(0, max),
            black: (blackPips[localTeam] ?? 0).clamp(0, max),
            max: max,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 38, color: Colors.white24),
          const SizedBox(width: 12),
          _TeamScorecards(
            label: 'Them',
            isLocal: false,
            red: (redPips[otherTeam] ?? 0).clamp(0, max),
            black: (blackPips[otherTeam] ?? 0).clamp(0, max),
            max: max,
          ),
        ],
      ),
    );
  }
}

class _TeamScorecards extends StatelessWidget {
  final String label;
  final bool isLocal;
  final int red;
  final int black;
  final int max;

  const _TeamScorecards({
    required this.label,
    required this.isLocal,
    required this.red,
    required this.black,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isLocal ? AppColors.accent : Colors.white70,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Six(isRed: true, pips: red, max: max),
            const SizedBox(width: 4),
            _Six(isRed: false, pips: black, max: max),
          ],
        ),
      ],
    );
  }
}

/// A miniature 6 card. [isRed] picks the red/black colour and the displayed
/// suit (♥ for red, ♠ for black). [pips] shows how many of the 6 spots are
/// "lit" — the rest are dim ghosts.
class _Six extends StatelessWidget {
  final bool isRed;
  final int pips;
  final int max;

  const _Six({required this.isRed, required this.pips, required this.max});

  @override
  Widget build(BuildContext context) {
    final lit = pips.clamp(0, max);
    final color = isRed ? const Color(0xFFD52F47) : Colors.black87;
    return Container(
      width: 30,
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
        boxShadow: lit >= max
            ? [
                BoxShadow(
                  color: color.withOpacity(0.7),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 1,
            left: 2,
            child: Text(
              '6',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
          ),
          // 6 pip grid: 2 columns × 3 rows.
          Center(
            child: _PipGrid(
              lit: lit,
              max: max,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipGrid extends StatelessWidget {
  final int lit;
  final int max;
  final Color color;

  const _PipGrid(
      {required this.lit, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final cols = 2;
    final rows = (max / cols).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(rows, (r) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(cols, (c) {
              final index = r * cols + c;
              final on = index < lit;
              return _Pip(on: on, color: color);
            }),
          );
        }),
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  final bool on;
  final Color color;
  const _Pip({required this.on, required this.color});

  @override
  Widget build(BuildContext context) {
    final radius = on ? 4.0 : 3.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: on ? color : color.withOpacity(0.18),
        shape: BoxShape.circle,
        boxShadow: on
            ? [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 3,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Convenience widget for the round-end overlay — large scorecards with a
/// caption explaining the rule ("Red 6 = wins, Black 6 = losses").
class TwentyNineScorecardsLarge extends StatelessWidget {
  final Map<int, int> redPips;
  final Map<int, int> blackPips;
  final int localTeam;
  final int max;

  const TwentyNineScorecardsLarge({
    super.key,
    required this.redPips,
    required this.blackPips,
    required this.localTeam,
    this.max = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: math.min(1.5, MediaQuery.of(context).size.width / 320),
      child: TwentyNineScorecards(
        redPips: redPips,
        blackPips: blackPips,
        localTeam: localTeam,
        max: max,
      ),
    );
  }
}
