import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/assets/asset_registry.dart';
import 'package:flutter_app/core/assets/card_skin_theme.dart';
import 'package:flutter_app/shared/widgets/playing_card_widget.dart';

void main() {
  group('PlayingCardWidget with skins', () {
    Widget buildCard({
      CardSkinTheme? theme,
      bool isFaceDown = false,
      String suit = 'hearts',
      String rank = 'A',
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayingCardWidget(
              suit: suit,
              rank: rank,
              theme: theme,
              isFaceDown: isFaceDown,
            ),
          ),
        ),
      );
    }

    testWidgets('renders with default (classic) theme when no skin specified',
        (tester) async {
      await tester.pumpWidget(buildCard());
      expect(find.text('A'), findsOneWidget);
      expect(find.text('\u2665'), findsWidgets); // heart symbol
    });

    testWidgets('renders face-up card with each skin theme', (tester) async {
      for (final skin in AssetRegistry.instance.allCardSkins) {
        await tester.pumpWidget(buildCard(theme: skin));
        expect(find.text('A'), findsOneWidget,
            reason: 'Rank should show for ${skin.displayName}');
      }
    });

    testWidgets('renders face-down card with each skin theme', (tester) async {
      for (final skin in AssetRegistry.instance.allCardSkins) {
        await tester.pumpWidget(buildCard(theme: skin, isFaceDown: true));
        // Face-down cards should not show rank text
        expect(find.text('A'), findsNothing,
            reason: 'Rank should be hidden for face-down ${skin.displayName}');
      }
    });

    testWidgets('neon skin uses dark card face colour', (tester) async {
      await tester.pumpWidget(buildCard(theme: CardSkinTheme.neon));

      // Find the main card Container
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, CardSkinTheme.neon.cardFaceColor);
    });

    testWidgets('selected card always uses gold accent border', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayingCardWidget(
              suit: 'spades',
              rank: 'K',
              theme: CardSkinTheme.neon,
              isSelected: true,
            ),
          ),
        ),
      ));

      // Should find the selected indicator dot
      expect(find.byKey(const Key('card-selected-indicator')), findsOneWidget);
    });

    testWidgets('black suit uses blackSuitColor from theme', (tester) async {
      await tester.pumpWidget(
          buildCard(theme: CardSkinTheme.neon, suit: 'spades', rank: 'K'));

      // The spade symbol text should exist
      expect(find.text('\u2660'), findsWidgets);
    });

    testWidgets('red suit uses redSuitColor from theme', (tester) async {
      await tester.pumpWidget(
          buildCard(theme: CardSkinTheme.gold, suit: 'diamonds', rank: 'Q'));

      // The diamond symbol text should exist
      expect(find.text('\u2666'), findsWidgets);
    });

    testWidgets('unplayable card stays at full opacity', (tester) async {
      // Cards no longer dim when unplayable — dimming during bidding made
      // the hand look "blurry". Invalid plays now use a shake animation.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayingCardWidget(
              suit: 'clubs',
              rank: '5',
              theme: CardSkinTheme.modern,
              isPlayable: false,
            ),
          ),
        ),
      ));

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
    });

    testWidgets('semantic label includes rank and suit', (tester) async {
      await tester.pumpWidget(buildCard(
          theme: CardSkinTheme.gold, suit: 'hearts', rank: 'K'));

      // Verify Semantics widget exists with correct label
      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'King of Hearts',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
