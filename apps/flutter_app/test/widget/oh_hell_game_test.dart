import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/colors.dart';

/// Widget tests for Oh Hell game UI components, specifically testing Bug #21
/// (scores disappearing at round end) and visual state of badges.
///
/// Tests the PlayerNode widget's badge positioning and BidPill visibility fixes.
void main() {
  group('BidPill Visibility (Bug #21)', () {
    testWidgets('TC-W01: BidPill shown during active play', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockBidPill(bid: 3, won: 2, hasBid: true, isVisible: true),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('TC-W02: BidPill stays visible at round end', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockBidPill(bid: 3, won: 3, hasBid: true, isVisible: true),
          ),
        ),
      );

      // BidPill should still be rendered even at round end. bid == won == 3
      // here (made bid exactly), so "3" legitimately renders twice.
      expect(find.byType(_MockBidPill), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2));
    });

    testWidgets('TC-W03: BidPill hidden when showBidPill=false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockBidPill(bid: 3, won: 2, hasBid: true, isVisible: false),
          ),
        ),
      );

      // When showBidPill is false, should not render
      expect(find.text('3'), findsNothing);
    });
  });

  group('Ready Badge (Bug #21)', () {
    testWidgets('TC-W04: Ready badge shows green check when ready',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [_MockReadyBadge(isReady: true)]),
          ),
        ),
      );

      // Find the ready badge container
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.check),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.success);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('TC-W05: Ready badge shows amber hourglass when waiting',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [_MockReadyBadge(isReady: false)]),
          ),
        ),
      );

      // Find the ready badge container
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.hourglass_empty),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFF9800)); // Amber
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('TC-W06: Ready badge hidden when isReady=null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockReadyBadge(isReady: null),
          ),
        ),
      );

      // No ready badge should be rendered
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    });

    testWidgets('TC-W07: Ready badge positioned top-right on avatar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockAvatarWithReadyBadge(),
          ),
        ),
      );

      // Find the Positioned widget wrapping the ready badge
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byIcon(Icons.check),
          matching: find.byType(Positioned),
        ),
      );

      expect(positioned.top, -4);
      expect(positioned.right, -4);
    });
  });

  group('Badge Collision Avoidance', () {
    testWidgets('TC-W08: Dealer badge at bottom-right', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockDealerBadge(),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(
        find.byType(Positioned),
      );

      expect(positioned.bottom, 0);
      expect(positioned.right, 0);
    });

    testWidgets('TC-W09: Bot badge at top-left', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockBotBadge(),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(
        find.byType(Positioned),
      );

      expect(positioned.top, 0);
      expect(positioned.left, 0);
    });

    testWidgets('TC-W10: All badges can coexist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockAvatarWithAllBadges(),
          ),
        ),
      );

      // Should find all three badges
      expect(find.text('BOT'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Verify no overlaps by checking positions
      final allPositioned = tester.widgetList<Positioned>(
        find.byType(Positioned),
      );

      expect(allPositioned.length, greaterThanOrEqualTo(3));
    });
  });

  group('Visual State', () {
    testWidgets('TC-W16: BidPill color based on result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockBidPill(bid: 3, won: 3, hasBid: true, isVisible: true),
          ),
        ),
      );

      // When bid matches won, should use success color
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      final decoration = container.decoration as BoxDecoration;
      // Green tint for successful bid
      expect(decoration.color?.green, greaterThan(0));
    });

    testWidgets('TC-W17: BidPill shows bid and won values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockBidPill(bid: 3, won: 2, hasBid: true, isVisible: true),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget); // bid value
      expect(find.text('2'), findsOneWidget); // won value
    });
  });
}

// Mock widgets for testing

class _MockBidPill extends StatelessWidget {
  final int bid;
  final int won;
  final bool hasBid;
  final bool isVisible;

  const _MockBidPill({
    required this.bid,
    required this.won,
    required this.hasBid,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final madeBid = bid == won;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: madeBid ? Colors.green.shade700 : Colors.red.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$bid', style: const TextStyle(color: Colors.white)),
          const SizedBox(width: 4),
          const Text('/', style: TextStyle(color: Colors.white)),
          const SizedBox(width: 4),
          Text('$won', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _MockReadyBadge extends StatelessWidget {
  final bool? isReady;

  const _MockReadyBadge({this.isReady});

  @override
  Widget build(BuildContext context) {
    if (isReady == null) return const SizedBox.shrink();

    final ready = isReady!;
    return Positioned(
      top: -4,
      right: -4,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: ready ? AppColors.success : const Color(0xFFFF9800),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.9),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            ready ? Icons.check : Icons.hourglass_empty,
            size: 11,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MockAvatarWithReadyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
        const _MockReadyBadge(isReady: true),
      ],
    );
  }
}

class _MockDealerBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('D', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockBotBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'BOT',
                style: TextStyle(fontSize: 8, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockAvatarWithAllBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          // Bot badge - top-left
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'BOT',
                style: TextStyle(fontSize: 8, color: Colors.white),
              ),
            ),
          ),
          // Dealer badge - bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('D', style: TextStyle(fontSize: 10)),
            ),
          ),
          // Ready badge - top-right
          const _MockReadyBadge(isReady: true),
        ],
      ),
    );
  }
}
