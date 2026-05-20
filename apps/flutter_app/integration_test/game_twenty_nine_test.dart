// Copied verbatim from 03-testing-strategy.md — full on-device integration test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_app/main.dart' as app;
import 'package:flutter_app/features/game/screens/game_screen.dart';
import 'package:flutter_app/shared/widgets/playing_card_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Twenty-Nine Game Flow — On-Device', () {
    testWidgets('complete game flow with bots', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // ── Login as guest ────────────────────────────────────────────────────
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // ── Select Twenty-Nine ────────────────────────────────────────────────
      await tester.tap(find.text('Twenty-Nine'));
      await tester.pumpAndSettle();

      // ── Create room ───────────────────────────────────────────────────────
      await tester.tap(find.text('Create Room'));
      await tester.pumpAndSettle();

      // ── Add 3 medium bots ─────────────────────────────────────────────────
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Add Bot'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Medium'));
        await tester.pumpAndSettle();
      }

      // ── Ready up ──────────────────────────────────────────────────────────
      await tester.tap(find.text('Ready'));
      await tester.pumpAndSettle();

      // ── Start game ────────────────────────────────────────────────────────
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ── Verify game screen loaded ─────────────────────────────────────────
      expect(find.byType(GameScreen), findsOneWidget);

      // ── Wait for bidding phase ────────────────────────────────────────────
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Bidding'), findsOneWidget);

      // ── Bid or pass ───────────────────────────────────────────────────────
      final bid16 = find.byKey(const Key('bid-16'));
      if (tester.any(bid16) &&
          tester.widget<ElevatedButton>(bid16).enabled) {
        await tester.tap(bid16);
      } else {
        await tester.tap(find.byKey(const Key('pass-button')));
      }
      await tester.pumpAndSettle();

      // ── Let bots play for a few seconds ───────────────────────────────────
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // ── Game should have progressed ───────────────────────────────────────
      expect(find.byType(PlayingCardWidget), findsWidgets);
    });
  });
}
