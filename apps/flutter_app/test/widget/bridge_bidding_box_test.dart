import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_bridge/game_bridge.dart';

import 'package:flutter_app/features/game/presentation/widgets/bridge_bidding_box.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  Widget buildBox({
    int seatIndex = 0,
    List<AuctionCall> history = const [],
  }) {
    return wrap(BridgeBiddingBox(
      seatIndex: seatIndex,
      auctionHistory: history,
      onBid: (_, __) {},
      onPass: () {},
      onDouble: () {},
      onRedouble: () {},
    ));
  }

  group('BridgeBiddingBox', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(buildBox());
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('bridge-bidding-box')), findsOneWidget);
    });

    testWidgets('Pass is always enabled', (tester) async {
      var passed = false;
      await tester.pumpWidget(wrap(BridgeBiddingBox(
        seatIndex: 0,
        auctionHistory: const [],
        onBid: (_, __) {},
        onPass: () => passed = true,
        onDouble: () {},
        onRedouble: () {},
      )));
      await tester.tap(find.byKey(const Key('bridge-pass')));
      expect(passed, isTrue);
    });

    testWidgets('Double is disabled with no prior bid', (tester) async {
      var doubled = false;
      await tester.pumpWidget(wrap(BridgeBiddingBox(
        seatIndex: 0,
        auctionHistory: const [],
        onBid: (_, __) {},
        onPass: () {},
        onDouble: () => doubled = true,
        onRedouble: () {},
      )));
      // Tapping a disabled-action GestureDetector should be a no-op.
      await tester.tap(find.byKey(const Key('bridge-double')));
      expect(doubled, isFalse);
    });

    testWidgets('1♣ cell is disabled after a 1♣ bid is in history',
        (tester) async {
      // East opened 1♣ — South (seat 2) must not be able to bid 1♣ again.
      const history = [
        AuctionCall(
          playerId: 'east',
          seatIndex: 1,
          type: 'bid',
          level: 1,
          denomination: BridgeDenomination.clubs,
        ),
      ];
      var tapped = false;
      await tester.pumpWidget(wrap(BridgeBiddingBox(
        seatIndex: 2,
        auctionHistory: history,
        onBid: (_, __) => tapped = true,
        onPass: () {},
        onDouble: () {},
        onRedouble: () {},
      )));
      await tester.tap(find.byKey(const Key('bridge-bid-1-clubs')));
      expect(tapped, isFalse,
          reason: 'A 1♣ bid is no longer legal after 1♣ has already been called.');

      // A higher bid (1♦) should still fire onBid.
      await tester.tap(find.byKey(const Key('bridge-bid-1-diamonds')));
      expect(tapped, isTrue);
    });

    testWidgets('Double becomes enabled after opponent bids', (tester) async {
      // East (seat 1, EW) bids — South (seat 2, NS) can double.
      const history = [
        AuctionCall(
          playerId: 'east',
          seatIndex: 1,
          type: 'bid',
          level: 1,
          denomination: BridgeDenomination.spades,
        ),
      ];
      var doubled = false;
      await tester.pumpWidget(wrap(BridgeBiddingBox(
        seatIndex: 2,
        auctionHistory: history,
        onBid: (_, __) {},
        onPass: () {},
        onDouble: () => doubled = true,
        onRedouble: () {},
      )));
      await tester.tap(find.byKey(const Key('bridge-double')));
      expect(doubled, isTrue);
    });

    testWidgets('Cannot double partner bid', (tester) async {
      // North (seat 0) bids — South (seat 2) is partner, must NOT be able to double.
      const history = [
        AuctionCall(
          playerId: 'north',
          seatIndex: 0,
          type: 'bid',
          level: 1,
          denomination: BridgeDenomination.spades,
        ),
      ];
      var doubled = false;
      await tester.pumpWidget(wrap(BridgeBiddingBox(
        seatIndex: 2,
        auctionHistory: history,
        onBid: (_, __) {},
        onPass: () {},
        onDouble: () => doubled = true,
        onRedouble: () {},
      )));
      await tester.tap(find.byKey(const Key('bridge-double')));
      expect(doubled, isFalse);
    });
  });
}
