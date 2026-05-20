import 'dart:math';

/// Describes a match in a bracket before it's persisted to the database.
class BracketMatch {
  final int round;
  final int matchNumber;
  final String bracketSide;
  String? player1Id;
  String? player2Id;
  int? player1Seed;
  int? player2Seed;
  bool isBye;
  String? nextMatchNumber; // match_number of next match (same bracket_side)
  int? nextMatchSlot; // 1 = player1, 2 = player2
  String? loserNextMatchNumber; // for double elim

  BracketMatch({
    required this.round,
    required this.matchNumber,
    required this.bracketSide,
    this.player1Id,
    this.player2Id,
    this.player1Seed,
    this.player2Seed,
    this.isBye = false,
    this.nextMatchNumber,
    this.nextMatchSlot,
    this.loserNextMatchNumber,
  });

  Map<String, dynamic> toInsertJson(String tournamentId) => {
        'tournament_id': tournamentId,
        'round': round,
        'match_number': matchNumber,
        'bracket_side': bracketSide,
        'player1_id': player1Id,
        'player2_id': player2Id,
        'player1_seed': player1Seed,
        'player2_seed': player2Seed,
        'status': isBye ? 'bye' : (player1Id != null && player2Id != null ? 'ready' : 'pending'),
      };
}

class BracketGenerator {
  // ── Single Elimination ──────────────────────────────────────────────────

  static List<BracketMatch> generateSingleElimination({
    required List<String> participantIds,
    List<int>? seeds,
  }) {
    final n = participantIds.length;
    if (n < 2) throw ArgumentError('Need at least 2 participants');

    final bracketSize = _nextPowerOf2(n);
    final totalRounds = (log(bracketSize) / log(2)).ceil();
    final effectiveSeeds = seeds ?? List.generate(n, (i) => i + 1);

    // Seed participants into bracket positions
    final seeded = _seedParticipants(participantIds, effectiveSeeds, bracketSize);

    final matches = <BracketMatch>[];
    var matchNumber = 1;

    // Round 1
    for (var i = 0; i < bracketSize ~/ 2; i++) {
      final p1 = seeded[i * 2];
      final p2 = seeded[i * 2 + 1];

      matches.add(BracketMatch(
        round: 1,
        matchNumber: matchNumber++,
        bracketSide: 'winners',
        player1Id: p1?.id,
        player2Id: p2?.id,
        player1Seed: p1?.seed,
        player2Seed: p2?.seed,
        isBye: p1 == null || p2 == null,
      ));
    }

    // Subsequent rounds (empty matches)
    var matchesInRound = bracketSize ~/ 4;
    for (var round = 2; round <= totalRounds; round++) {
      for (var i = 0; i < matchesInRound; i++) {
        matches.add(BracketMatch(
          round: round,
          matchNumber: matchNumber++,
          bracketSide: 'winners',
        ));
      }
      matchesInRound = (matchesInRound / 2).ceil();
      if (matchesInRound < 1) matchesInRound = 1;
    }

    _linkBracketMatches(matches, 'winners');
    return matches;
  }

  // ── Double Elimination ──────────────────────────────────────────────────

  static List<BracketMatch> generateDoubleElimination({
    required List<String> participantIds,
    List<int>? seeds,
  }) {
    // Winners bracket
    final winnersMatches = generateSingleElimination(
      participantIds: participantIds,
      seeds: seeds,
    );

    final n = participantIds.length;
    final bracketSize = _nextPowerOf2(n);
    final winnersRounds = (log(bracketSize) / log(2)).ceil();

    final matches = List<BracketMatch>.from(winnersMatches);
    var matchNumber = winnersMatches.length + 1;

    // Losers bracket: (winnersRounds - 1) * 2 rounds
    final losersRounds = (winnersRounds - 1) * 2;
    var matchesInRound = bracketSize ~/ 4;

    for (var round = 1; round <= losersRounds; round++) {
      for (var i = 0; i < matchesInRound; i++) {
        matches.add(BracketMatch(
          round: round,
          matchNumber: matchNumber++,
          bracketSide: 'losers',
        ));
      }

      if (round.isEven && matchesInRound > 1) {
        matchesInRound ~/= 2;
      }
    }

    // Grand finals
    matches.add(BracketMatch(
      round: 1,
      matchNumber: matchNumber++,
      bracketSide: 'finals',
    ));

    // Grand finals reset (if losers bracket winner wins game 1)
    matches.add(BracketMatch(
      round: 2,
      matchNumber: matchNumber++,
      bracketSide: 'finals',
    ));

    return matches;
  }

  // ── Round Robin ─────────────────────────────────────────────────────────

  static List<BracketMatch> generateRoundRobin({
    required List<String> participantIds,
  }) {
    final n = participantIds.length;
    if (n < 2) throw ArgumentError('Need at least 2 participants');

    final matches = <BracketMatch>[];
    final participants = List<String?>.from(participantIds);

    // If odd number, add a bye slot
    if (n.isOdd) {
      participants.add(null);
    }

    final rounds = participants.length - 1;
    final matchesPerRound = participants.length ~/ 2;
    var matchNumber = 1;

    for (var round = 1; round <= rounds; round++) {
      for (var i = 0; i < matchesPerRound; i++) {
        final home = participants[i];
        final away = participants[participants.length - 1 - i];

        if (home != null && away != null) {
          matches.add(BracketMatch(
            round: round,
            matchNumber: matchNumber++,
            bracketSide: 'winners',
            player1Id: home,
            player2Id: away,
          ));
        }
      }

      // Rotate participants (keep first fixed)
      final last = participants.removeLast();
      participants.insert(1, last);
    }

    return matches;
  }

  // ── Swiss ───────────────────────────────────────────────────────────────

  /// Generate first round of Swiss pairings (by seed order).
  /// Subsequent rounds are generated dynamically based on standings.
  static List<BracketMatch> generateSwissFirstRound({
    required List<String> participantIds,
    List<int>? seeds,
  }) {
    final n = participantIds.length;
    if (n < 2) throw ArgumentError('Need at least 2 participants');

    final effectiveSeeds = seeds ?? List.generate(n, (i) => i + 1);

    // Sort by seed
    final indexed = List.generate(n, (i) => i);
    indexed.sort((a, b) => effectiveSeeds[a].compareTo(effectiveSeeds[b]));

    final matches = <BracketMatch>[];
    var matchNumber = 1;

    // Pair top half vs bottom half: seed 1 vs seed n/2+1, etc.
    final halfSize = (n / 2).ceil();
    for (var i = 0; i < halfSize; i++) {
      final opponentIndex = i + halfSize;
      if (opponentIndex >= n) {
        // Bye
        matches.add(BracketMatch(
          round: 1,
          matchNumber: matchNumber++,
          bracketSide: 'winners',
          player1Id: participantIds[indexed[i]],
          player1Seed: effectiveSeeds[indexed[i]],
          isBye: true,
        ));
      } else {
        matches.add(BracketMatch(
          round: 1,
          matchNumber: matchNumber++,
          bracketSide: 'winners',
          player1Id: participantIds[indexed[i]],
          player2Id: participantIds[indexed[opponentIndex]],
          player1Seed: effectiveSeeds[indexed[i]],
          player2Seed: effectiveSeeds[indexed[opponentIndex]],
        ));
      }
    }

    return matches;
  }

  /// Generate next Swiss round based on current standings.
  /// Pairs players with similar records, avoiding rematches.
  static List<BracketMatch> generateSwissNextRound({
    required int roundNumber,
    required List<SwissStanding> standings,
    required Set<String> previousPairings,
    int startingMatchNumber = 1,
  }) {
    // Sort by points desc, then buchholz desc
    final sorted = List<SwissStanding>.from(standings)
      ..sort((a, b) {
        final pointsDiff = b.points.compareTo(a.points);
        if (pointsDiff != 0) return pointsDiff;
        return b.buchholz.compareTo(a.buchholz);
      });

    final matches = <BracketMatch>[];
    final paired = <String>{};
    var matchNumber = startingMatchNumber;

    for (var i = 0; i < sorted.length; i++) {
      if (paired.contains(sorted[i].playerId)) continue;

      final player = sorted[i];
      String? opponent;

      // Find closest-ranked unpaired opponent who hasn't played this player
      for (var j = i + 1; j < sorted.length; j++) {
        final candidate = sorted[j];
        if (paired.contains(candidate.playerId)) continue;

        final pairingKey = _pairingKey(player.playerId, candidate.playerId);
        if (!previousPairings.contains(pairingKey)) {
          opponent = candidate.playerId;
          paired.add(candidate.playerId);
          break;
        }
      }

      paired.add(player.playerId);

      if (opponent != null) {
        matches.add(BracketMatch(
          round: roundNumber,
          matchNumber: matchNumber++,
          bracketSide: 'winners',
          player1Id: player.playerId,
          player2Id: opponent,
        ));
      } else {
        // Bye
        matches.add(BracketMatch(
          round: roundNumber,
          matchNumber: matchNumber++,
          bracketSide: 'winners',
          player1Id: player.playerId,
          isBye: true,
        ));
      }
    }

    return matches;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static int _nextPowerOf2(int n) {
    var power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  /// Calculate recommended number of Swiss rounds.
  static int recommendedSwissRounds(int participants) {
    return (log(participants) / log(2)).ceil();
  }

  static List<_SeededPlayer?> _seedParticipants(
    List<String> participants,
    List<int> seeds,
    int bracketSize,
  ) {
    final seeded = List<_SeededPlayer?>.filled(bracketSize, null);
    final seedOrder = _getSeedOrder(bracketSize);

    for (var i = 0; i < participants.length; i++) {
      seeded[seedOrder[i]] = _SeededPlayer(participants[i], seeds[i]);
    }

    return seeded;
  }

  static List<int> _getSeedOrder(int size) {
    if (size == 2) return [0, 1];

    final halfSize = size ~/ 2;
    final topHalf = _getSeedOrder(halfSize);
    final bottomHalf = topHalf.map((i) => size - 1 - i).toList();

    final result = <int>[];
    for (var i = 0; i < halfSize; i++) {
      result.add(topHalf[i]);
      result.add(bottomHalf[i]);
    }

    return result;
  }

  static void _linkBracketMatches(List<BracketMatch> matches, String side) {
    final sideMatches = matches.where((m) => m.bracketSide == side).toList();
    final byRound = <int, List<BracketMatch>>{};
    for (final match in sideMatches) {
      byRound.putIfAbsent(match.round, () => []).add(match);
    }

    final rounds = byRound.keys.toList()..sort();

    for (var i = 0; i < rounds.length - 1; i++) {
      final currentRound = byRound[rounds[i]]!;
      final nextRound = byRound[rounds[i + 1]]!;

      for (var j = 0; j < currentRound.length; j++) {
        final nextMatchIndex = j ~/ 2;
        if (nextMatchIndex < nextRound.length) {
          currentRound[j].nextMatchNumber =
              nextRound[nextMatchIndex].matchNumber.toString();
          currentRound[j].nextMatchSlot = (j % 2) + 1;
        }
      }
    }
  }

  static String _pairingKey(String a, String b) {
    return a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';
  }
}

class _SeededPlayer {
  final String id;
  final int seed;
  const _SeededPlayer(this.id, this.seed);
}

/// Standings entry for Swiss pairing.
class SwissStanding {
  final String playerId;
  final int points;
  final double buchholz;

  const SwissStanding({
    required this.playerId,
    required this.points,
    this.buchholz = 0,
  });
}
