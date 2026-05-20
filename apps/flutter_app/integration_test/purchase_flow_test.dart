import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_app/main.dart' as app;

/// Purchase flow integration tests — run against a StoreKit sandbox / Google
/// Play billing sandbox environment.  These tests are skipped in CI unless
/// the PURCHASE_TESTS=true env var is set, since they require a real payment
/// sandbox and cannot be mocked at the device driver level.

const _runPurchaseTests =
    bool.fromEnvironment('PURCHASE_TESTS', defaultValue: false);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Purchase Flow — Sandbox', skip: !_runPurchaseTests, () {
    testWidgets('upgrade to Pro tier is available', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // Navigate to settings → subscription
      await tester.tap(find.byKey(const Key('profile-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upgrade'));
      await tester.pumpAndSettle();

      // Subscription page should show Pro and Max options
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('\$3.99 / month'), findsOneWidget);
      expect(find.text('\$7.99 / month'), findsOneWidget);
    });

    testWidgets('purchasing Pro removes ads from home screen', (tester) async {
      // This test requires a pre-configured sandbox account that has
      // already completed the Pro purchase.  It verifies the entitlement
      // is picked up at app launch.
      app.main();
      await tester.pumpAndSettle();

      // Login with sandbox pro account (credentials set via env)
      final email = const String.fromEnvironment('SANDBOX_PRO_EMAIL');
      final password = const String.fromEnvironment('SANDBOX_PRO_PASSWORD');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('email-field')), email);
      await tester.enterText(find.byKey(const Key('password-field')), password);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // No banner ad should be visible for Pro users
      expect(find.byKey(const Key('banner-ad')), findsNothing);
    });

    testWidgets('rewarded ad flow awards coins', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // Find and tap the "Watch ad for coins" button
      await tester.tap(find.byKey(const Key('watch-ad-button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Simulate ad completion (sandbox dismissal)
      await tester.tap(find.byKey(const Key('ad-close-button')));
      await tester.pumpAndSettle();

      // Coins should have been credited
      expect(find.byKey(const Key('coins-credited-snackbar')), findsOneWidget);
    });
  });
}
