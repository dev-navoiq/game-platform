import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../data/tournament_models.dart';

/// Horizontally scrollable bracket visualization for elimination tournaments.
class BracketView extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String? currentUserId;
  final void Function(TournamentMatch)? onMatchTap;

  const BracketView({
    super.key,
    required this.matches,
    this.currentUserId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Text(
          'Bracket not yet generated',
          style: TextStyle(color: AppColors.textFeltMuted),
        ),
      );
    }

    // Separate by bracket side
    final winnersMatches =
        matches.where((m) => m.bracketSide == BracketSide.winners).toList();
    final losersMatches =
        matches.where((m) => m.bracketSide == BracketSide.losers).toList();
    final finalsMatches =
        matches.where((m) => m.bracketSide == BracketSide.finals).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (winnersMatches.isNotEmpty) ...[
            if (losersMatches.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Winners Bracket',
                  style: TextStyle(
                    color: AppColors.textOnFelt,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            _BracketSection(
              matches: winnersMatches,
              currentUserId: currentUserId,
              onMatchTap: onMatchTap,
            ),
          ],
          if (losersMatches.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Losers Bracket',
              style: TextStyle(
                color: AppColors.textOnFelt,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            _BracketSection(
              matches: losersMatches,
              currentUserId: currentUserId,
              onMatchTap: onMatchTap,
            ),
          ],
          if (finalsMatches.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Grand Finals',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            _BracketSection(
              matches: finalsMatches,
              currentUserId: currentUserId,
              onMatchTap: onMatchTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _BracketSection extends StatelessWidget {
  final List<TournamentMatch> matches;
  final String? currentUserId;
  final void Function(TournamentMatch)? onMatchTap;

  const _BracketSection({
    required this.matches,
    this.currentUserId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final roundsMap = <int, List<TournamentMatch>>{};
    for (final match in matches) {
      roundsMap.putIfAbsent(match.round, () => []).add(match);
    }
    final rounds = roundsMap.keys.toList()..sort();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rounds.map((round) {
        return _BracketRound(
          roundNumber: round,
          totalRounds: rounds.length,
          matches: roundsMap[round]!,
          currentUserId: currentUserId,
          onMatchTap: onMatchTap,
        );
      }).toList(),
    );
  }
}

class _BracketRound extends StatelessWidget {
  final int roundNumber;
  final int totalRounds;
  final List<TournamentMatch> matches;
  final String? currentUserId;
  final void Function(TournamentMatch)? onMatchTap;

  const _BracketRound({
    required this.roundNumber,
    required this.totalRounds,
    required this.matches,
    this.currentUserId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          // Round header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(GlassTokens.radiusSmall),
            ),
            child: Text(
              _getRoundName(),
              style: const TextStyle(
                color: AppColors.textOnFelt,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...matches.asMap().entries.map((entry) {
            final spacing = _calculateSpacing(entry.key);
            return Padding(
              padding: EdgeInsets.only(top: spacing),
              child: MatchCard(
                match: entry.value,
                currentUserId: currentUserId,
                onTap:
                    onMatchTap != null ? () => onMatchTap!(entry.value) : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getRoundName() {
    final roundsFromEnd = totalRounds - roundNumber + 1;
    switch (roundsFromEnd) {
      case 1:
        return 'Finals';
      case 2:
        return 'Semi-Finals';
      case 3:
        return 'Quarter-Finals';
      default:
        return 'Round $roundNumber';
    }
  }

  double _calculateSpacing(int matchIndex) {
    if (matchIndex == 0) return 0;
    final baseSpacing = 16.0;
    final multiplier = pow(2, roundNumber - 1).toDouble();
    return baseSpacing * multiplier;
  }
}

/// A single match card showing two players and their scores.
class MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final String? currentUserId;
  final VoidCallback? onTap;

  const MatchCard({
    super.key,
    required this.match,
    this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMyMatch = match.player1Id == currentUserId ||
        match.player2Id == currentUserId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMyMatch
              ? AppColors.accent.withOpacity(0.15)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(GlassTokens.radiusSmall),
          border: Border.all(
            color: match.isCompleted
                ? AppColors.success.withOpacity(0.4)
                : isMyMatch
                    ? AppColors.accent.withOpacity(0.4)
                    : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlayerRow(
              name: match.player1Name ?? (match.player1Id != null ? '...' : 'TBD'),
              seed: match.player1Seed,
              score: match.player1Score,
              isWinner: match.winnerId != null && match.winnerId == match.player1Id,
              isCurrentUser: match.player1Id == currentUserId,
            ),
            Divider(height: 6, color: Colors.white.withOpacity(0.15)),
            _PlayerRow(
              name: match.player2Name ?? (match.player2Id != null ? '...' : 'TBD'),
              seed: match.player2Seed,
              score: match.player2Score,
              isWinner: match.winnerId != null && match.winnerId == match.player2Id,
              isCurrentUser: match.player2Id == currentUserId,
            ),
            if (match.isLive) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (match.isBye) ...[
              const SizedBox(height: 4),
              Text(
                'BYE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String name;
  final int? seed;
  final int? score;
  final bool isWinner;
  final bool isCurrentUser;

  const _PlayerRow({
    required this.name,
    this.seed,
    this.score,
    required this.isWinner,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (seed != null)
          SizedBox(
            width: 18,
            child: Text(
              '$seed',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (seed != null) const SizedBox(width: 4),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isWinner
                  ? AppColors.success
                  : AppColors.textOnFelt,
              fontWeight: isWinner || isCurrentUser
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (score != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isWinner
                  ? AppColors.success.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                color: isWinner ? AppColors.success : AppColors.textOnFelt,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(left: 3),
            child: Icon(Icons.emoji_events, color: AppColors.accent, size: 14),
          ),
      ],
    );
  }
}
