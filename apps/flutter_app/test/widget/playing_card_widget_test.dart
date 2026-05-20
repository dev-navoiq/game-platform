import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/shared/widgets/playing_card_widget.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('PlayingCardWidget', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayingCardWidget(suit: 'hearts', rank: 'A'),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows rank and suit when face-up', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayingCardWidget(suit: 'hearts', rank: 'A'),
      ));
      expect(find.text('A'), findsWidgets);
    });

    testWidgets('face-down card hides rank', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayingCardWidget(suit: 'hearts', rank: 'A', isFaceDown: true),
      ));
      expect(find.text('A'), findsNothing);
    });

    testWidgets('selected card shows selection indicator', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayingCardWidget(suit: 'spades', rank: 'K', isSelected: true),
      ));
      // Widget should reflect selected state — look for a visual indicator
      expect(find.byKey(const Key('card-selected-indicator')), findsOneWidget);
    });

    testWidgets('non-playable card is visually dimmed', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayingCardWidget(suit: 'clubs', rank: '7', isPlayable: false),
      ));
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PlayingCardWidget),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(opacity.opacity, lessThan(1.0));
    });

    testWidgets('tap on playable card fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        PlayingCardWidget(
          suit: 'diamonds',
          rank: 'Q',
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.byType(PlayingCardWidget));
      expect(tapped, isTrue);
    });

    testWidgets('tap on non-playable card does not fire onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        PlayingCardWidget(
          suit: 'diamonds',
          rank: 'Q',
          isPlayable: false,
          onTap: () => tapped = true,
        ),
      ));
      await tester.tap(find.byType(PlayingCardWidget));
      expect(tapped, isFalse);
    });

    testWidgets('has correct semantic label', (tester) async {
      await tester.pumpWidget(wrap(
        const PlayingCardWidget(suit: 'hearts', rank: 'A'),
      ));
      expect(
        find.bySemanticsLabel(RegExp(r'Ace of Hearts', caseSensitive: false)),
        findsOneWidget,
      );
    });
  });
}
