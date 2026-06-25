// Demo drive for recording a short local-run clip. Navigates the main screens
// with deliberate pauses so the recording is watchable. Defensive: each step is
// guarded so a missing widget never aborts the whole drive.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo drive — login to lobby', (tester) async {
    Future<void> hold([int s = 2]) =>
        Future.delayed(Duration(seconds: s));
    Future<void> tapText(String label, {int settle = 3}) async {
      final f = find.text(label);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await tester.pumpAndSettle(Duration(seconds: settle));
      }
    }

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await hold(2); // show login screen

    await tapText('Continue as Guest');
    await hold(3); // show home / "Choose a Game"

    await tapText('Twenty-Nine');
    await hold(3); // show the Twenty-Nine lobby

    // Back to home and peek another game lobby.
    final back = find.byTooltip('Back');
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
    await hold(2);

    await tapText('Oh Hell');
    await hold(3);
  });
}
