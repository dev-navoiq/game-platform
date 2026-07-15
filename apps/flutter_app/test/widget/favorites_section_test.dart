import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/favorites/providers/favorites_providers.dart';
import 'package:flutter_app/features/history/providers/history_providers.dart';
import 'package:flutter_app/features/home/presentation/widgets/favorites_section.dart';

/// Unmount the tree and advance fake time so flutter_animate's internal
/// (uncancelable) delay timers elapse before the binding's pending-timer
/// check at test end.
Future<void> flushAnimationTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  group('FavoritesSection', () {
    testWidgets('shows nothing when no favorites and no recent games',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider
                .overrideWith((ref) => FavoritesNotifier(null)),
            recentGameTypesProvider
                .overrideWith((ref) => Future.value(<String>[])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FavoritesSection()),
          ),
        ),
      );

      // Bounded pump: the redesigned tiles run looping idle animations, so
      // pumpAndSettle would never settle.
      await tester.pump(const Duration(milliseconds: 600));
      // Should render SizedBox.shrink — no visible text
      expect(find.text('Favorites'), findsNothing);
      expect(find.text('Recently Played'), findsNothing);

      await flushAnimationTimers(tester);
    });

    testWidgets('shows Favorites section when favorites exist',
        (tester) async {
      final notifier = FavoritesNotifier(null);
      // Simulate having favorites
      await notifier.add('chess');
      await notifier.add('ludo');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => notifier),
            recentGameTypesProvider
                .overrideWith((ref) => Future.value(<String>[])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: FavoritesSection()),
            ),
          ),
        ),
      );

      // Bounded pump: the redesigned tiles run looping idle animations, so
      // pumpAndSettle would never settle.
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Chess'), findsOneWidget);
      expect(find.text('Ludo'), findsOneWidget);

      await flushAnimationTimers(tester);
    });

    testWidgets('shows Recently Played section when recent games exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider
                .overrideWith((ref) => FavoritesNotifier(null)),
            recentGameTypesProvider
                .overrideWith((ref) => Future.value(['hearts', 'spades'])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: FavoritesSection()),
            ),
          ),
        ),
      );

      // Bounded pump: the redesigned tiles run looping idle animations, so
      // pumpAndSettle would never settle.
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Recently Played'), findsOneWidget);
      expect(find.text('Hearts'), findsOneWidget);
      expect(find.text('Spades'), findsOneWidget);

      await flushAnimationTimers(tester);
    });

    testWidgets('star icon toggles on tap', (tester) async {
      final notifier = FavoritesNotifier(null);
      await notifier.add('chess');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            favoritesProvider.overrideWith((ref) => notifier),
            recentGameTypesProvider
                .overrideWith((ref) => Future.value(<String>[])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: FavoritesSection()),
            ),
          ),
        ),
      );

      // Bounded pump: the redesigned tiles run looping idle animations, so
      // pumpAndSettle would never settle.
      await tester.pump(const Duration(milliseconds: 600));

      // Should have star icons: 1 in header + 1 on card (redesign uses the
      // rounded variant)
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));

      // Tap the card's star (size 20) to unfavorite
      await tester.tap(find.byIcon(Icons.star_rounded).last);
      // Bounded pump: the redesigned tiles run looping idle animations, so
      // pumpAndSettle would never settle.
      await tester.pump(const Duration(milliseconds: 600));

      // After toggling, chess should be removed — section should disappear
      expect(find.text('Favorites'), findsNothing);

      await flushAnimationTimers(tester);
    });
  });
}
