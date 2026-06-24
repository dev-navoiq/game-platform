import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_app/main.dart' as app;

/// Smoke test — verifies the app launches without crashing on a real device.
///
/// This file is also the canonical target of the recorded UI test pipeline
/// (`.github/workflows/ui-tests-mac.yml`): when a PR carries the
/// `needs-ui-tests` label, the self-hosted macOS runner boots a dedicated
/// CI-iPhone-17 simulator, runs this suite, and uploads a screen recording
/// for human review.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch', () {
    testWidgets('app starts without error', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should see either the auth screen or home screen
      final hasWelcome = find.text('Continue as Guest').evaluate().isNotEmpty;
      final hasHome = find.text('Choose a Game').evaluate().isNotEmpty;

      expect(hasWelcome || hasHome, isTrue,
          reason: 'Expected to see the welcome or home screen after launch');
    });

    testWidgets('guest login is accessible', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      if (find.text('Continue as Guest').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continue as Guest'));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text('Choose a Game'), findsOneWidget);
      }
    });
  });
}
