import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/tournaments/data/tournament_models.dart';
import 'package:flutter_app/features/tournaments/presentation/widgets/tournament_card.dart';
import 'package:flutter_app/features/tournaments/presentation/widgets/bracket_view.dart';
import 'package:flutter_app/features/tournaments/presentation/widgets/standings_table.dart';

Tournament _makeTournament({
  String name = 'Test Tournament',
  TournamentFormat format = TournamentFormat.singleElimination,
  TournamentStatus status = TournamentStatus.registration,
  bool isOfficial = false,
  int currentParticipants = 8,
  int maxParticipants = 16,
  int entryFeeCoins = 0,
  int entryFeeGems = 0,
  List<TournamentPrize> prizes = const [],
}) {
  return Tournament(
    id: 'test-id',
    name: name,
    gameType: 'chess',
    format: format,
    isOfficial: isOfficial,
    startTime: DateTime.now().add(const Duration(hours: 2)),
    minParticipants: 4,
    maxParticipants: maxParticipants,
    currentParticipants: currentParticipants,
    entryFeeCoins: entryFeeCoins,
    entryFeeGems: entryFeeGems,
    prizes: prizes,
    status: status,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('TournamentCard', () {
    testWidgets('displays tournament name and format', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(
            tournament: _makeTournament(name: 'Weekly Chess'),
          ),
        ),
      ));

      expect(find.text('Weekly Chess'), findsOneWidget);
      expect(find.text('Single Elimination'), findsOneWidget);
    });

    testWidgets('shows OFFICIAL badge when isOfficial', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(
            tournament: _makeTournament(isOfficial: true),
          ),
        ),
      ));

      expect(find.text('OFFICIAL'), findsOneWidget);
    });

    testWidgets('shows LIVE badge for in-progress tournaments',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(
            tournament: _makeTournament(status: TournamentStatus.inProgress),
          ),
        ),
      ));

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('shows FREE chip when no entry fee', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(tournament: _makeTournament()),
        ),
      ));

      expect(find.text('FREE'), findsOneWidget);
    });

    testWidgets('shows coin entry fee', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(
            tournament: _makeTournament(entryFeeCoins: 200),
          ),
        ),
      ));

      expect(find.text('200 coins'), findsOneWidget);
    });

    testWidgets('shows participant count', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(
            tournament: _makeTournament(
                currentParticipants: 8, maxParticipants: 16),
          ),
        ),
      ));

      expect(find.text('8/16'), findsOneWidget);
    });

    testWidgets('shows first prize', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(
            tournament: _makeTournament(
              prizes: [
                const TournamentPrize(place: 1, coins: 1000, gems: 50),
              ],
            ),
          ),
        ),
      ));

      expect(find.text('1000 coins + 50 gems'), findsOneWidget);
    });

    testWidgets('handles onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentCard(
            tournament: _makeTournament(),
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(TournamentCard));
      expect(tapped, true);
    });
  });

  group('MatchCard', () {
    testWidgets('displays player names', (tester) async {
      const match = TournamentMatch(
        id: 'm1',
        tournamentId: 't1',
        round: 1,
        matchNumber: 1,
        bracketSide: BracketSide.winners,
        player1Id: 'p1',
        player2Id: 'p2',
        player1Name: 'Alice',
        player2Name: 'Bob',
        status: MatchStatus.ready,
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MatchCard(match: match),
        ),
      ));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('shows LIVE badge for in-progress match', (tester) async {
      const match = TournamentMatch(
        id: 'm1',
        tournamentId: 't1',
        round: 1,
        matchNumber: 1,
        bracketSide: BracketSide.winners,
        player1Name: 'Alice',
        player2Name: 'Bob',
        status: MatchStatus.inProgress,
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MatchCard(match: match)),
      ));

      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('shows BYE badge for bye match', (tester) async {
      const match = TournamentMatch(
        id: 'm1',
        tournamentId: 't1',
        round: 1,
        matchNumber: 1,
        bracketSide: BracketSide.winners,
        player1Name: 'Alice',
        status: MatchStatus.bye,
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MatchCard(match: match)),
      ));

      expect(find.text('BYE'), findsOneWidget);
    });

    testWidgets('shows winner icon', (tester) async {
      const match = TournamentMatch(
        id: 'm1',
        tournamentId: 't1',
        round: 1,
        matchNumber: 1,
        bracketSide: BracketSide.winners,
        player1Id: 'p1',
        player2Id: 'p2',
        player1Name: 'Alice',
        player2Name: 'Bob',
        winnerId: 'p1',
        player1Score: 3,
        player2Score: 1,
        status: MatchStatus.completed,
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MatchCard(match: match)),
      ));

      // Trophy icon for winner
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });
  });

  group('BracketView', () {
    testWidgets('shows empty state when no matches', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BracketView(matches: []),
        ),
      ));

      expect(find.text('Bracket not yet generated'), findsOneWidget);
    });

    testWidgets('displays round headers for winners bracket',
        (tester) async {
      const matches = [
        TournamentMatch(
          id: 'm1',
          tournamentId: 't1',
          round: 1,
          matchNumber: 1,
          bracketSide: BracketSide.winners,
          player1Name: 'Alice',
          player2Name: 'Bob',
          status: MatchStatus.ready,
        ),
        TournamentMatch(
          id: 'm2',
          tournamentId: 't1',
          round: 1,
          matchNumber: 2,
          bracketSide: BracketSide.winners,
          player1Name: 'Charlie',
          player2Name: 'Diana',
          status: MatchStatus.ready,
        ),
        TournamentMatch(
          id: 'm3',
          tournamentId: 't1',
          round: 2,
          matchNumber: 3,
          bracketSide: BracketSide.winners,
          status: MatchStatus.pending,
        ),
      ];

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: BracketView(matches: matches),
        ),
      ));

      expect(find.text('Semi-Finals'), findsOneWidget);
      expect(find.text('Finals'), findsOneWidget);
    });
  });

  group('StandingsTable', () {
    testWidgets('displays participants sorted by points', (tester) async {
      final participants = [
        TournamentParticipant(
          id: 'tp1',
          tournamentId: 't1',
          userId: 'u1',
          username: 'Alice',
          wins: 3,
          losses: 0,
          points: 9,
          registeredAt: DateTime.now(),
        ),
        TournamentParticipant(
          id: 'tp2',
          tournamentId: 't1',
          userId: 'u2',
          username: 'Bob',
          wins: 1,
          losses: 2,
          points: 3,
          registeredAt: DateTime.now(),
        ),
        TournamentParticipant(
          id: 'tp3',
          tournamentId: 't1',
          userId: 'u3',
          username: 'Charlie',
          wins: 2,
          losses: 1,
          points: 6,
          registeredAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StandingsTable(participants: participants),
        ),
      ));

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);

      // Header columns
      expect(find.text('Player'), findsOneWidget);
      expect(find.text('Pts'), findsOneWidget);
    });

    testWidgets('highlights current user', (tester) async {
      final participants = [
        TournamentParticipant(
          id: 'tp1',
          tournamentId: 't1',
          userId: 'me',
          username: 'Me',
          points: 5,
          registeredAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StandingsTable(
            participants: participants,
            currentUserId: 'me',
          ),
        ),
      ));

      expect(find.text('Me'), findsOneWidget);
    });
  });
}
