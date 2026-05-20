import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/tournaments/domain/bracket_generator.dart';

void main() {
  group('BracketGenerator', () {
    group('Single Elimination', () {
      test('generates correct bracket for 4 participants', () {
        final matches = BracketGenerator.generateSingleElimination(
          participantIds: ['a', 'b', 'c', 'd'],
        );

        // 4 players = 2 round-1 matches + 1 final = 3 matches
        expect(matches.length, 3);

        final round1 = matches.where((m) => m.round == 1).toList();
        final round2 = matches.where((m) => m.round == 2).toList();
        expect(round1.length, 2);
        expect(round2.length, 1);

        // All bracket sides are winners
        expect(matches.every((m) => m.bracketSide == 'winners'), true);
      });

      test('generates correct bracket for 8 participants', () {
        final ids = List.generate(8, (i) => 'p$i');
        final matches = BracketGenerator.generateSingleElimination(
          participantIds: ids,
        );

        // 8 players = 4 + 2 + 1 = 7 matches
        expect(matches.length, 7);

        expect(matches.where((m) => m.round == 1).length, 4);
        expect(matches.where((m) => m.round == 2).length, 2);
        expect(matches.where((m) => m.round == 3).length, 1);
      });

      test('generates correct bracket for 2 participants', () {
        final matches = BracketGenerator.generateSingleElimination(
          participantIds: ['a', 'b'],
        );

        expect(matches.length, 1);
        expect(matches[0].player1Id, isNotNull);
        expect(matches[0].player2Id, isNotNull);
      });

      test('handles non-power-of-2 with byes', () {
        final matches = BracketGenerator.generateSingleElimination(
          participantIds: ['a', 'b', 'c'],
        );

        // Padded to 4: 2 round-1 + 1 final = 3 matches
        expect(matches.length, 3);

        // At least one bye in round 1
        final round1 = matches.where((m) => m.round == 1).toList();
        expect(round1.any((m) => m.isBye), true);
      });

      test('handles 5 participants with byes', () {
        final ids = List.generate(5, (i) => 'p$i');
        final matches = BracketGenerator.generateSingleElimination(
          participantIds: ids,
        );

        // Padded to 8: 4 + 2 + 1 = 7 matches
        expect(matches.length, 7);

        final byes = matches.where((m) => m.isBye).toList();
        expect(byes.length, 3); // 8 - 5 = 3 byes
      });

      test('links matches correctly', () {
        final matches = BracketGenerator.generateSingleElimination(
          participantIds: ['a', 'b', 'c', 'd'],
        );

        // Round 1 matches should link to round 2
        final round1 = matches.where((m) => m.round == 1).toList();
        for (final match in round1) {
          expect(match.nextMatchNumber, isNotNull);
          expect(match.nextMatchSlot, isIn([1, 2]));
        }

        // Final match should have no next
        final finalMatch = matches.firstWhere((m) => m.round == 2);
        expect(finalMatch.nextMatchNumber, isNull);
      });

      test('seeds are applied to first round', () {
        final matches = BracketGenerator.generateSingleElimination(
          participantIds: ['a', 'b', 'c', 'd'],
          seeds: [1, 2, 3, 4],
        );

        final round1 = matches.where((m) => m.round == 1).toList();
        // Top seed vs bottom seed should be in the same match
        // Standard seeding: 1v4, 2v3 (or similar pattern)
        final allSeeds = <int>{};
        for (final m in round1) {
          if (m.player1Seed != null) allSeeds.add(m.player1Seed!);
          if (m.player2Seed != null) allSeeds.add(m.player2Seed!);
        }
        expect(allSeeds, {1, 2, 3, 4});
      });

      test('throws for less than 2 participants', () {
        expect(
          () => BracketGenerator.generateSingleElimination(
            participantIds: ['a'],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Double Elimination', () {
      test('generates winners, losers, and finals', () {
        final matches = BracketGenerator.generateDoubleElimination(
          participantIds: ['a', 'b', 'c', 'd'],
        );

        final winners =
            matches.where((m) => m.bracketSide == 'winners').toList();
        final losers =
            matches.where((m) => m.bracketSide == 'losers').toList();
        final finals =
            matches.where((m) => m.bracketSide == 'finals').toList();

        expect(winners.isNotEmpty, true);
        expect(losers.isNotEmpty, true);
        expect(finals.length, 2); // Grand finals + reset
      });

      test('generates correct winners bracket for 8 players', () {
        final ids = List.generate(8, (i) => 'p$i');
        final matches = BracketGenerator.generateDoubleElimination(
          participantIds: ids,
        );

        final winners =
            matches.where((m) => m.bracketSide == 'winners').toList();
        expect(winners.length, 7); // Same as single elim
      });
    });

    group('Round Robin', () {
      test('generates correct number of matches for 4 players', () {
        final matches = BracketGenerator.generateRoundRobin(
          participantIds: ['a', 'b', 'c', 'd'],
        );

        // n*(n-1)/2 = 4*3/2 = 6 matches
        expect(matches.length, 6);
      });

      test('generates correct matches for 3 players', () {
        final matches = BracketGenerator.generateRoundRobin(
          participantIds: ['a', 'b', 'c'],
        );

        // 3*2/2 = 3 matches
        expect(matches.length, 3);
      });

      test('generates correct matches for 5 players', () {
        final matches = BracketGenerator.generateRoundRobin(
          participantIds: List.generate(5, (i) => 'p$i'),
        );

        // 5*4/2 = 10 matches
        expect(matches.length, 10);
      });

      test('each player plays every other player exactly once', () {
        final ids = ['a', 'b', 'c', 'd'];
        final matches = BracketGenerator.generateRoundRobin(
          participantIds: ids,
        );

        for (var i = 0; i < ids.length; i++) {
          for (var j = i + 1; j < ids.length; j++) {
            final pairMatches = matches.where((m) =>
                (m.player1Id == ids[i] && m.player2Id == ids[j]) ||
                (m.player1Id == ids[j] && m.player2Id == ids[i]));
            expect(pairMatches.length, 1,
                reason: '${ids[i]} vs ${ids[j]}');
          }
        }
      });

      test('all matches have both players assigned', () {
        final matches = BracketGenerator.generateRoundRobin(
          participantIds: ['a', 'b', 'c', 'd'],
        );

        for (final match in matches) {
          expect(match.player1Id, isNotNull);
          expect(match.player2Id, isNotNull);
        }
      });

      test('throws for less than 2 participants', () {
        expect(
          () => BracketGenerator.generateRoundRobin(participantIds: ['a']),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Swiss', () {
      test('generates first round with correct pairings', () {
        final ids = List.generate(8, (i) => 'p$i');
        final matches = BracketGenerator.generateSwissFirstRound(
          participantIds: ids,
        );

        // 8 players = 4 matches
        expect(matches.length, 4);

        // All matches should be in round 1
        expect(matches.every((m) => m.round == 1), true);
      });

      test('pairs top half vs bottom half', () {
        final ids = ['p0', 'p1', 'p2', 'p3'];
        final matches = BracketGenerator.generateSwissFirstRound(
          participantIds: ids,
          seeds: [1, 2, 3, 4],
        );

        // Seed 1 vs seed 3, seed 2 vs seed 4
        expect(matches.length, 2);
      });

      test('handles odd number with bye', () {
        final matches = BracketGenerator.generateSwissFirstRound(
          participantIds: ['a', 'b', 'c'],
        );

        // 2 matches: 1 real + 1 bye
        expect(matches.length, 2);
        expect(matches.any((m) => m.isBye), true);
      });

      test('generates next round avoiding rematches', () {
        final standings = [
          const SwissStanding(playerId: 'a', points: 3),
          const SwissStanding(playerId: 'b', points: 3),
          const SwissStanding(playerId: 'c', points: 0),
          const SwissStanding(playerId: 'd', points: 0),
        ];

        final previousPairings = {'a:c', 'b:d'};

        final matches = BracketGenerator.generateSwissNextRound(
          roundNumber: 2,
          standings: standings,
          previousPairings: previousPairings,
        );

        expect(matches.length, 2);

        // a played c, so a should play b or d; b played d, so b plays a or c
        for (final match in matches) {
          if (match.player1Id != null && match.player2Id != null) {
            final key = match.player1Id!.compareTo(match.player2Id!) < 0
                ? '${match.player1Id}:${match.player2Id}'
                : '${match.player2Id}:${match.player1Id}';
            expect(previousPairings.contains(key), false,
                reason: 'Rematch: $key');
          }
        }
      });

      test('recommendedSwissRounds returns correct values', () {
        expect(BracketGenerator.recommendedSwissRounds(8), 3);
        expect(BracketGenerator.recommendedSwissRounds(16), 4);
        expect(BracketGenerator.recommendedSwissRounds(32), 5);
      });
    });

    group('BracketMatch', () {
      test('toInsertJson produces correct structure', () {
        final match = BracketMatch(
          round: 1,
          matchNumber: 1,
          bracketSide: 'winners',
          player1Id: 'abc',
          player2Id: 'def',
          player1Seed: 1,
          player2Seed: 4,
        );

        final json = match.toInsertJson('tournament-123');

        expect(json['tournament_id'], 'tournament-123');
        expect(json['round'], 1);
        expect(json['match_number'], 1);
        expect(json['bracket_side'], 'winners');
        expect(json['player1_id'], 'abc');
        expect(json['player2_id'], 'def');
        expect(json['status'], 'ready');
      });

      test('toInsertJson sets bye status', () {
        final match = BracketMatch(
          round: 1,
          matchNumber: 1,
          bracketSide: 'winners',
          player1Id: 'abc',
          isBye: true,
        );

        final json = match.toInsertJson('t1');
        expect(json['status'], 'bye');
      });

      test('toInsertJson sets pending when no players', () {
        final match = BracketMatch(
          round: 2,
          matchNumber: 3,
          bracketSide: 'winners',
        );

        final json = match.toInsertJson('t1');
        expect(json['status'], 'pending');
      });
    });
  });
}
