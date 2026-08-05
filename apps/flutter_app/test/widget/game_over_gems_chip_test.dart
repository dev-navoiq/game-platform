// #55 — gem display on the game-over dialogs.
//
// Gems are never granted at regular game end, so the chip must stay hidden
// for the everyday zero case and appear only when a flow actually pays gems
// (e.g. tournament payouts routed through the dialog).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/game/presentation/widgets/game_over_dialog.dart';
import 'package:flutter_app/features/game/presentation/widgets/ranked_game_over_dialog.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('GameOverDialog gems chip', () {
    testWidgets('hidden when gemsEarned is 0', (tester) async {
      await tester.pumpWidget(_wrap(const GameOverDialog(
        isWinner: true,
        coinsEarned: 50,
        xpEarned: 30,
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.diamond), findsNothing);
    });

    testWidgets('shown with amount when gemsEarned > 0', (tester) async {
      await tester.pumpWidget(_wrap(const GameOverDialog(
        isWinner: true,
        coinsEarned: 50,
        xpEarned: 30,
        gemsEarned: 25,
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.diamond), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
    });

    testWidgets('gems-only receipt still renders the reward row',
        (tester) async {
      await tester.pumpWidget(_wrap(const GameOverDialog(
        isWinner: true,
        gemsEarned: 10,
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.diamond), findsOneWidget);
    });
  });

  group('RankedGameOverDialog gems chip', () {
    const results = [
      RankedPlayerResult(
          playerId: 'p1', name: 'You', emoji: '🐯', score: 10, isLocal: true),
      RankedPlayerResult(
          playerId: 'p2', name: 'Bot', emoji: '🤖', score: 5, isLocal: false),
    ];

    testWidgets('hidden when gemsEarned is 0', (tester) async {
      await tester.pumpWidget(_wrap(const RankedGameOverDialog(
        results: results,
        coinsEarned: 50,
        xpEarned: 30,
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.diamond), findsNothing);
    });

    testWidgets('shown with amount when gemsEarned > 0', (tester) async {
      await tester.pumpWidget(_wrap(const RankedGameOverDialog(
        results: results,
        coinsEarned: 50,
        xpEarned: 30,
        gemsEarned: 40,
      )));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byIcon(Icons.diamond), findsOneWidget);
      expect(find.text('+40'), findsOneWidget);
    });
  });
}
