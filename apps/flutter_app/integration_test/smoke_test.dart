import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Minimal integration test that proves the runner + simulator + record
/// pipeline works end-to-end without depending on the full `flutter_app`
/// initialization (Supabase init, Riverpod scope, plugin channels, etc.).
///
/// Deliberately does NOT import `flutter_app/main.dart` so a failure here
/// isolates to the iOS build / sim-launch path, not app-level startup.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke: minimal MaterialApp renders on simulator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'SMOKE OK',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SMOKE OK'), findsOneWidget);
  });
}
