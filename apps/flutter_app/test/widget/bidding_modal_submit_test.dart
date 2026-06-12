// BiddingModal "is submitting" guard.
//
// The user complaint: tapping Confirm Bid does nothing visible until the
// server responds, so users keep tapping and accidentally submit twice.
// The fix: on first tap, mark the modal as submitting (spinner replaces
// the label, all bid actions disabled). A 5-second safety timer resets
// the state if the server never confirms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/game/presentation/widgets/bidding_modal.dart';

void main() {
  group('BiddingModal submit guard', () {
    testWidgets('first Confirm tap fires once; second tap is ignored',
        (tester) async {
      var fireCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BiddingModal(
            minBid: 0,
            maxBid: 4,
            onBidSelected: (_) => fireCount++,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Select bid 2 then tap Confirm.
      await tester.tap(find.byKey(const Key('bid-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-confirm')));
      await tester.pump();

      // Tap Confirm again — should be ignored because we're submitting.
      await tester.tap(find.byKey(const Key('bid-confirm')));
      await tester.pump();

      expect(fireCount, 1,
          reason: 'submitting guard should prevent double-fire');

      // Drain the safety timer so the test doesn't leak.
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('Confirm button shows spinner after tap', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BiddingModal(
            minBid: 0,
            maxBid: 4,
            onBidSelected: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // No spinner before submit.
      expect(find.byKey(const Key('bid-confirm-spinner')), findsNothing);

      await tester.tap(find.byKey(const Key('bid-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-confirm')));
      await tester.pump();

      // Spinner appears immediately.
      expect(find.byKey(const Key('bid-confirm-spinner')), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('grid tiles are disabled while submitting', (tester) async {
      var fireCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BiddingModal(
            minBid: 0,
            maxBid: 4,
            onBidSelected: (_) => fireCount++,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bid-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-confirm')));
      await tester.pump();

      // While submitting, tapping a different bid value should NOT change
      // selection (and any subsequent Confirm tap would still send '2',
      // not the new selection).
      await tester.tap(find.byKey(const Key('bid-3')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-confirm')));
      await tester.pump();

      expect(fireCount, 1,
          reason: 'grid tiles must be disabled to prevent mid-flight '
              'selection changes');

      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('Pass button respects the submitting guard', (tester) async {
      var passCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BiddingModal(
            minBid: 0,
            maxBid: 4,
            showPassButton: true,
            onBidSelected: (_) {},
            onPass: () => passCount++,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bid-pass')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-pass')));
      await tester.pump();

      expect(passCount, 1);

      await tester.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('safety timer restores grid after 5 seconds', (tester) async {
      var fireCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BiddingModal(
            minBid: 0,
            maxBid: 4,
            onBidSelected: (_) => fireCount++,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bid-2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('bid-confirm')));
      await tester.pump();
      expect(find.byKey(const Key('bid-confirm-spinner')), findsOneWidget);

      // Advance time past the 5-second safety reset.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      // Spinner gone, grid live again.
      expect(find.byKey(const Key('bid-confirm-spinner')), findsNothing);

      // User can now retry.
      await tester.tap(find.byKey(const Key('bid-confirm')));
      await tester.pump();
      expect(fireCount, 2);

      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });
}
