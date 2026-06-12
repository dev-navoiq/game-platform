import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/shared/animations/gameplay/bidding_pulse.dart';

/// A throwaway StatefulWidget whose State is exposed via a GlobalKey. The
/// test uses `same()` identity on the State to assert it wasn't recreated
/// when the wrapper's props changed.
class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key});

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  int initRunCount = 1;

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 40, height: 40);
}

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  group('BiddingPulse', () {
    testWidgets('renders child both when active and inactive', (tester) async {
      await tester.pumpWidget(host(
        const BiddingPulse(isActive: false, child: Text('hand')),
      ));
      expect(find.text('hand'), findsOneWidget);

      await tester.pumpWidget(host(
        const BiddingPulse(isActive: true, child: Text('hand')),
      ));
      await tester.pump();
      expect(find.text('hand'), findsOneWidget);
    });

    // REGRESSION TEST for the card-jitter bug. The old build returned
    // `widget.child` directly when inactive and a wrapped `AnimatedBuilder`
    // when active — that shape change unmounted+remounted the child subtree
    // every time isActive flipped, which destroyed CardFanAnimation's
    // staggered-entry State and stranded cards mid-deal-in.
    testWidgets('preserves child State across isActive toggle', (tester) async {
      final probeKey = GlobalKey<_StateProbeState>();

      await tester.pumpWidget(host(
        BiddingPulse(isActive: false, child: _StateProbe(key: probeKey)),
      ));
      final originalState = probeKey.currentState;
      expect(originalState, isNotNull,
          reason: 'Probe should mount on first build');

      // Toggle ON
      await tester.pumpWidget(host(
        BiddingPulse(isActive: true, child: _StateProbe(key: probeKey)),
      ));
      await tester.pump();
      expect(probeKey.currentState, same(originalState),
          reason: 'Child State must persist across isActive false→true');

      // Toggle OFF
      await tester.pumpWidget(host(
        BiddingPulse(isActive: false, child: _StateProbe(key: probeKey)),
      ));
      await tester.pump();
      expect(probeKey.currentState, same(originalState),
          reason: 'Child State must persist across isActive true→false');

      // Toggle ON again
      await tester.pumpWidget(host(
        BiddingPulse(isActive: true, child: _StateProbe(key: probeKey)),
      ));
      await tester.pump();
      expect(probeKey.currentState, same(originalState),
          reason: 'Child State must persist across repeated toggles');
    });

    testWidgets('renders DecoratedBox on every build (stable widget shape)',
        (tester) async {
      await tester.pumpWidget(host(
        const BiddingPulse(isActive: false, child: SizedBox(key: ValueKey('c'))),
      ));
      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));

      await tester.pumpWidget(host(
        const BiddingPulse(isActive: true, child: SizedBox(key: ValueKey('c'))),
      ));
      await tester.pump();
      expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));
    });
  });
}
