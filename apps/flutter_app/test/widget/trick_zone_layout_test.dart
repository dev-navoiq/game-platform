// TrickZone places each card on the vector from zone-center toward the
// player's seat. These tests check that the chosen card position actually
// differs by seat — local player's card lands below center, the opposite
// player's card lands above, the left player's card lands left of center,
// the right player's card lands right.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'package:flutter_app/features/game/presentation/widgets/trick_zone.dart';

void main() {
  const local = 'p0';
  const left = 'p1';
  const top = 'p2';
  const right = 'p3';
  const playerOrder = [local, left, top, right];

  TrickCard tc(String pid, int seat, Suit suit, Rank rank) => TrickCard(
        playerId: pid,
        card: PlayingCard(suit, rank),
        seatIndex: seat,
      );

  Widget host(List<TrickCard> trick) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: TrickZone(
              currentTrick: trick,
              playerOrder: playerOrder,
              localPlayerId: local,
              fullTrickSize: 4,
            ),
          ),
        ),
      );

  // Helper: get the on-screen y coordinate (global) of the first painted
  // card matching the given rank. We assert relative positions only —
  // exact pixels depend on screen size.
  double xOf(WidgetTester tester, Finder f) =>
      tester.getCenter(f).dx;
  double yOf(WidgetTester tester, Finder f) =>
      tester.getCenter(f).dy;

  group('TrickZone vector layout', () {
    testWidgets("local player's card lands below center", (tester) async {
      await tester.pumpWidget(host([
        tc(local, 0, Suit.spades, Rank.ace),
      ]));
      await tester.pumpAndSettle();

      final localCard = find.text('♠').first;
      final zone = find.byType(TrickZone);
      expect(yOf(tester, localCard), greaterThan(yOf(tester, zone)),
          reason: 'local player sits south → card center should be below '
              'the TrickZone center');
    });

    testWidgets("opposite player's card lands above center", (tester) async {
      await tester.pumpWidget(host([
        tc(top, 2, Suit.hearts, Rank.king),
      ]));
      await tester.pumpAndSettle();

      final topCard = find.text('♥').first;
      final zone = find.byType(TrickZone);
      expect(yOf(tester, topCard), lessThan(yOf(tester, zone)),
          reason: 'opposite seat sits north → card should be above center');
    });

    testWidgets('left and right seats land on opposite sides of center',
        (tester) async {
      await tester.pumpWidget(host([
        tc(left, 1, Suit.clubs, Rank.queen),
        tc(right, 3, Suit.diamonds, Rank.jack),
      ]));
      await tester.pumpAndSettle();

      final leftCard = find.text('♣').first;
      final rightCard = find.text('♦').first;
      expect(xOf(tester, leftCard), lessThan(xOf(tester, rightCard)),
          reason: 'left seat card should sit left of right seat card');
    });

    testWidgets('all 4 cards form a cross (different positions)',
        (tester) async {
      await tester.pumpWidget(host([
        tc(local, 0, Suit.spades, Rank.two),
        tc(left, 1, Suit.clubs, Rank.three),
        tc(top, 2, Suit.hearts, Rank.four),
        tc(right, 3, Suit.diamonds, Rank.five),
      ]));
      await tester.pumpAndSettle();

      final s = find.text('♠').first;
      final c = find.text('♣').first;
      final h = find.text('♥').first;
      final d = find.text('♦').first;

      // No two cards should share both axes — they're spread around the
      // perimeter.
      final positions = [
        tester.getCenter(s),
        tester.getCenter(c),
        tester.getCenter(h),
        tester.getCenter(d),
      ];
      for (var i = 0; i < positions.length; i++) {
        for (var j = i + 1; j < positions.length; j++) {
          final dist = (positions[i] - positions[j]).distance;
          expect(dist, greaterThan(20),
              reason: 'each card should be in its own seat region '
                  '($i vs $j too close: $dist px)');
        }
      }
    });
  });

  group('TrickZone grid fallback', () {
    testWidgets('falls back to grid when localPlayerId is null',
        (tester) async {
      // Hearts/Spades shells don't pass localPlayerId — make sure the
      // widget still renders cards in a row instead of crashing.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TrickZone(
                currentTrick: [
                  tc(local, 0, Suit.spades, Rank.ace),
                  tc(left, 1, Suit.clubs, Rank.king),
                ],
                playerOrder: playerOrder,
                // localPlayerId omitted → fallback path
                fullTrickSize: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both cards should be visible.
      expect(find.text('♠'), findsWidgets);
      expect(find.text('♣'), findsWidgets);
    });
  });
}
