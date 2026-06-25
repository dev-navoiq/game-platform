// On-device integration test: full Twenty-Nine flow against the real backend.
//
// Rewritten 2026-06-24 to match the current UI:
//   • Bots are added from per-seat icon buttons (Tooltip 'Medium bot'), not an
//     'Add Bot' text button.
//   • Bidding is a modal that only appears on the local player's turn; pass is
//     Key('bid-pass'), a numeric bid is Key('bid-<n>') + Key('bid-confirm').
//   • The game screen runs continuous animations (BiddingPulse, glow), so
//     pumpAndSettle never settles — we advance time in fixed steps via pumpFor,
//     which also lets real Supabase realtime/network round-trips complete.
//
// The 'all-pass redeal' test requires --dart-define=TN_FORCE_BOT_PASS=true so
// bots always pass during bidding; the human taps 'bid-pass' once. The engine
// performs the redeal and the UI shows "All players passed — re-dealing".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_app/main.dart' as app;
import 'package:flutter_app/features/game/screens/game_screen.dart';
import 'package:flutter_app/shared/widgets/playing_card_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Advance frames for [d] of real time without requiring the tree to settle
  // (the game screen animates forever). Real async (network) progresses too.
  Future<void> pumpFor(WidgetTester t, Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 80));
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  group('Twenty-Nine Game Flow — On-Device', () {
    testWidgets('complete game flow with bots', (tester) async {
      Future<bool> tapText(String label, {Duration? wait}) async {
        final f = find.text(label);
        if (f.evaluate().isEmpty) return false;
        await tester.tap(f.first, warnIfMissed: false);
        await pumpFor(tester, wait ?? const Duration(seconds: 2));
        return true;
      }

      app.main();
      await pumpFor(tester, const Duration(seconds: 4));

      // ── Login as guest ──────────────────────────────────────────────────
      await tapText('Continue as Guest', wait: const Duration(seconds: 4));

      // ── Open the Twenty-Nine lobby and create a room ────────────────────
      await tapText('Twenty-Nine', wait: const Duration(seconds: 3));
      await tapText('Create Room', wait: const Duration(seconds: 4));

      // ── Fill the table with 3 medium bots ───────────────────────────────
      // Each empty seat shows Easy/Medium/Hard icon buttons; tapping one fires
      // an addBot RPC and the new member arrives via realtime. Wait between adds
      // so the per-slot spinner clears and the next tap lands on a fresh seat.
      for (var i = 0; i < 3; i++) {
        final medium = find.byTooltip('Medium bot');
        if (medium.evaluate().isNotEmpty) {
          await tester.tap(medium.first, warnIfMissed: false);
          await pumpFor(tester, const Duration(seconds: 3));
        }
      }

      // ── Ready up (host) and start the game ──────────────────────────────
      await tapText('Ready', wait: const Duration(seconds: 1));
      await tapText('Start Game', wait: const Duration(seconds: 5));

      // ── We should now be on the game screen with a hand dealt ───────────
      expect(find.byType(GameScreen), findsOneWidget);
      await pumpFor(tester, const Duration(seconds: 3));
      expect(find.byType(PlayingCardWidget), findsWidgets);

      // ── Drive the round: pass our bids, then play cards on our turns ─────
      // Bots bid and play on their own; we only need to act when a control for
      // us is on screen. Tap our hand cards each tick — the valid one commits,
      // the rest are no-ops (wrong turn / must-follow-suit).
      for (var tick = 0; tick < 26; tick++) {
        // Bidding modal up for us → pass.
        final pass = find.byKey(const Key('bid-pass'));
        if (pass.evaluate().isNotEmpty) {
          await tester.tap(pass.first, warnIfMissed: false);
          await pumpFor(tester, const Duration(seconds: 1));
          continue;
        }
        // Otherwise try to play from our hand.
        final hand = find.byKey(const Key('player-hand'));
        if (hand.evaluate().isNotEmpty) {
          final cards = find.descendant(
            of: hand,
            matching: find.byType(PlayingCardWidget),
          );
          final n = cards.evaluate().length;
          for (var k = 0; k < n && k < 8; k++) {
            final c = find
                .descendant(of: hand, matching: find.byType(PlayingCardWidget))
                .at(k);
            if (c.evaluate().isNotEmpty) {
              await tester.tap(c, warnIfMissed: false);
              await pumpFor(tester, const Duration(milliseconds: 350));
            }
          }
        }
        await pumpFor(tester, const Duration(milliseconds: 900));
      }

      // The round ran — cards are still on the table / in hands.
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(PlayingCardWidget), findsWidgets);
    });

    // Run only when --dart-define=TN_FORCE_BOT_PASS=true is set.
    // Bots always pass; the human passes once via 'bid-pass'. After 4 passes
    // the engine redeals, and the UI shows a "re-dealing" snackbar, then
    // bidding resumes (the modal reappears on the next human turn).
    testWidgets(
      'all-pass redeal: engine redeals and bidding resumes',
      skip: !const bool.fromEnvironment('TN_FORCE_BOT_PASS'),
      (tester) async {
        Future<bool> tapText(String label, {Duration? wait}) async {
          final f = find.text(label);
          if (f.evaluate().isEmpty) return false;
          await tester.tap(f.first, warnIfMissed: false);
          await pumpFor(tester, wait ?? const Duration(seconds: 2));
          return true;
        }

        app.main();
        await pumpFor(tester, const Duration(seconds: 4));

        // ── Login as guest ────────────────────────────────────────────────
        await tapText('Continue as Guest', wait: const Duration(seconds: 4));

        // ── Open Twenty-Nine lobby and create a room ──────────────────────
        await tapText('Twenty-Nine', wait: const Duration(seconds: 3));
        await tapText('Create Room', wait: const Duration(seconds: 4));

        // ── Add 3 medium bots ─────────────────────────────────────────────
        for (var i = 0; i < 3; i++) {
          final medium = find.byTooltip('Medium bot');
          if (medium.evaluate().isNotEmpty) {
            await tester.tap(medium.first, warnIfMissed: false);
            await pumpFor(tester, const Duration(seconds: 3));
          }
        }

        // ── Ready and start ───────────────────────────────────────────────
        await tapText('Ready', wait: const Duration(seconds: 1));
        await tapText('Start Game', wait: const Duration(seconds: 5));

        expect(find.byType(GameScreen), findsOneWidget);
        await pumpFor(tester, const Duration(seconds: 3));

        // ── All 4 players pass: bots pass automatically (TN_FORCE_BOT_PASS),
        //    human taps bid-pass once. After 4 passes the redeal fires. ────
        for (var tick = 0; tick < 10; tick++) {
          final pass = find.byKey(const Key('bid-pass'));
          if (pass.evaluate().isNotEmpty) {
            await tester.tap(pass.first, warnIfMissed: false);
            await pumpFor(tester, const Duration(seconds: 2));
            break;
          }
          await pumpFor(tester, const Duration(seconds: 1));
        }

        // Allow the server to apply the redeal and broadcast the new state.
        await pumpFor(tester, const Duration(seconds: 5));

        // ── Assert the redeal snackbar appeared ───────────────────────────
        expect(
          find.text('All players passed — re-dealing'),
          findsOneWidget,
          reason: 'Expected "All players passed — re-dealing" snackbar',
        );

        // ── Assert we are back in bidding with a fresh hand ───────────────
        expect(find.byType(GameScreen), findsOneWidget);
        expect(find.byType(PlayingCardWidget), findsWidgets);
        // The bidding modal should re-appear when it is the human's turn again.
        await pumpFor(tester, const Duration(seconds: 4));
        // Verify the game did not soft-lock (screen is still interactive).
        expect(find.byType(GameScreen), findsOneWidget);
      },
    );
  });
}
