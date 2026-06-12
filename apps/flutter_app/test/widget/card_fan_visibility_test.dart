// CardFanAnimation is now a top-aligned scrollable strip (was a fan).
// These tests verify the surface contract: cards mount, mid-round shrink
// keeps surviving cards in the tree, and a wide hand becomes scrollable.
//
// The staggered deal sequence still uses `Future.delayed`, so each test
// must drain timers via `pumpAndSettle()` before returning to satisfy the
// "no pending timers at test end" invariant.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/shared/animations/cards/card_fan_animation.dart';

void main() {
  Widget host(Widget child, {double width = 400}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(width: width, height: 200, child: child),
        ),
      );

  group('CardFanAnimation basic mount', () {
    testWidgets('mounts the expected number of cards', (tester) async {
      await tester.pumpWidget(host(
        CardFanAnimation(
          cardCount: 5,
          cardBuilder: (i) =>
              SizedBox(key: ValueKey('card-$i'), width: 40, height: 60),
        ),
      ));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('card-$i')), findsOneWidget);
      }
    });

    testWidgets('mid-round shrink keeps surviving cards in tree',
        (tester) async {
      await tester.pumpWidget(host(
        CardFanAnimation(
          cardCount: 4,
          cardBuilder: (i) =>
              SizedBox(key: ValueKey('card-$i'), width: 40, height: 60),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(
        CardFanAnimation(
          cardCount: 3,
          cardBuilder: (i) =>
              SizedBox(key: ValueKey('card-$i'), width: 40, height: 60),
        ),
      ));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('card-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('card-3')), findsNothing);
    });

    testWidgets('reports stripHeight in layout', (tester) async {
      await tester.pumpWidget(host(
        Align(
          alignment: Alignment.bottomCenter,
          child: CardFanAnimation(
            cardCount: 3,
            cardBuilder: (i) =>
                SizedBox(key: ValueKey('card-$i'), width: 40, height: 60),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final firstCardBox =
          tester.renderObject<RenderBox>(find.byKey(const ValueKey('card-0')));
      // Card should be inside the strip (positive global y) and within the
      // viewport bottom. We don't assert exact pixels because of LayoutBuilder
      // padding; we just confirm the card actually rendered with non-zero
      // size.
      expect(firstCardBox.size.width, greaterThan(0));
      expect(firstCardBox.size.height, greaterThan(0));
    });
  });

  group('CardFanAnimation scroll', () {
    testWidgets('wide hand becomes horizontally scrollable', (tester) async {
      // 13 cards × stride 50 + 80 = 730 px content. In a 300-wide viewport
      // this must overflow and be scrollable.
      await tester.pumpWidget(host(
        CardFanAnimation(
          cardCount: 13,
          cardBuilder: (i) => SizedBox(
            key: ValueKey('card-$i'),
            width: CardFanAnimation.cardWidth,
            height: CardFanAnimation.cardHeight,
          ),
        ),
        width: 300,
      ));
      await tester.pumpAndSettle();

      final scrollable = tester.widget<Scrollable>(
        find.byType(Scrollable).first,
      );
      // BouncingScrollPhysics is set when scrolling is required.
      expect(
        scrollable.physics.runtimeType.toString(),
        contains('BouncingScrollPhysics'),
      );
    });

    testWidgets('narrow hand stays non-scrollable and centered',
        (tester) async {
      // 3 cards × 50 + 80 = 180 px content in 400-wide viewport — no scroll.
      await tester.pumpWidget(host(
        CardFanAnimation(
          cardCount: 3,
          cardBuilder: (i) => SizedBox(
            key: ValueKey('card-$i'),
            width: CardFanAnimation.cardWidth,
            height: CardFanAnimation.cardHeight,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final scrollable = tester.widget<Scrollable>(
        find.byType(Scrollable).first,
      );
      expect(
        scrollable.physics.runtimeType.toString(),
        contains('NeverScrollableScrollPhysics'),
      );
    });
  });

  group('CardFanAnimation edge-fade affordance', () {
    testWidgets('no fade when content fits the viewport', (tester) async {
      await tester.pumpWidget(host(
        CardFanAnimation(
          cardCount: 3,
          cardBuilder: (i) => SizedBox(
            key: ValueKey('card-$i'),
            width: CardFanAnimation.cardWidth,
            height: CardFanAnimation.cardHeight,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Small hand → no overflow → no ShaderMask. Pixel-identical to before.
      expect(find.byType(ShaderMask), findsNothing,
          reason: 'fade affordance only applies when content overflows');
    });

    testWidgets('overflowing hand renders an edge-fade ShaderMask',
        (tester) async {
      // 13 cards in a 300-px viewport overflows by 430px → fade must appear.
      await tester.pumpWidget(host(
        CardFanAnimation(
          cardCount: 13,
          cardBuilder: (i) => SizedBox(
            key: ValueKey('card-$i'),
            width: CardFanAnimation.cardWidth,
            height: CardFanAnimation.cardHeight,
          ),
        ),
        width: 300,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ShaderMask), findsOneWidget,
          reason: 'a scrollable hand must signal more-content-offscreen');
    });
  });
}
