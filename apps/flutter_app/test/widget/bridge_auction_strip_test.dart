import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_bridge/game_bridge.dart';

import 'package:flutter_app/features/game/presentation/widgets/bridge_auction_strip.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('BridgeAuctionStrip', () {
    testWidgets('renders empty without throwing', (tester) async {
      await tester.pumpWidget(wrap(const BridgeAuctionStrip(
        auctionHistory: [],
        dealerIndex: 0,
      )));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('bridge-auction-strip')), findsOneWidget);
    });

    testWidgets(
        '3-call history renders bid + double + pass with correct glyphs',
        (tester) async {
      const history = [
        // North (dealer, seat 0) opens 1♠
        AuctionCall(
          playerId: 'n',
          seatIndex: 0,
          type: 'bid',
          level: 1,
          denomination: BridgeDenomination.spades,
        ),
        // East doubles
        AuctionCall(playerId: 'e', seatIndex: 1, type: 'double'),
        // South passes
        AuctionCall(playerId: 's', seatIndex: 2, type: 'pass'),
      ];

      await tester.pumpWidget(wrap(const BridgeAuctionStrip(
        auctionHistory: history,
        dealerIndex: 0,
      )));

      // Headers N E S W are present
      expect(find.text('N'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);

      // Specific call cells rendered with the correct keys
      expect(find.byKey(const Key('auction-bid')), findsOneWidget);
      expect(find.byKey(const Key('auction-double')), findsOneWidget);
      expect(find.byKey(const Key('auction-pass')), findsOneWidget);

      // Pass glyph 'P' appears
      expect(find.text('P'), findsOneWidget);
      // Double glyph 'X' appears
      expect(find.text('X'), findsOneWidget);
    });

    testWidgets('redouble glyph is XX', (tester) async {
      const history = [
        AuctionCall(
          playerId: 'n',
          seatIndex: 0,
          type: 'bid',
          level: 1,
          denomination: BridgeDenomination.spades,
        ),
        AuctionCall(playerId: 'e', seatIndex: 1, type: 'double'),
        AuctionCall(playerId: 's', seatIndex: 2, type: 'redouble'),
      ];

      await tester.pumpWidget(wrap(const BridgeAuctionStrip(
        auctionHistory: history,
        dealerIndex: 0,
      )));

      expect(find.byKey(const Key('auction-redouble')), findsOneWidget);
      expect(find.text('XX'), findsOneWidget);
    });
  });
}
