import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/favorites/providers/favorites_providers.dart';
import 'package:flutter_app/features/history/providers/history_providers.dart';
import 'package:flutter_app/features/home/presentation/widgets/favorites_section.dart';

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

      await tester.pumpAndSettle();
      // Should render SizedBox.shrink — no visible text
      expect(find.text('Favorites'), findsNothing);
      expect(find.text('Recently Played'), findsNothing);
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

      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Chess'), findsOneWidget);
      expect(find.text('Ludo'), findsOneWidget);
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

      await tester.pumpAndSettle();

      expect(find.text('Recently Played'), findsOneWidget);
      expect(find.text('Hearts'), findsOneWidget);
      expect(find.text('Spades'), findsOneWidget);
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

      await tester.pumpAndSettle();

      // Should have star icons: 1 in header + 1 on card
      expect(find.byIcon(Icons.star), findsNWidgets(2));

      // Tap the card's star (size 20) to unfavorite
      await tester.tap(find.byIcon(Icons.star).last);
      await tester.pumpAndSettle();

      // After toggling, chess should be removed — section should disappear
      expect(find.text('Favorites'), findsNothing);
    });
  });
}
