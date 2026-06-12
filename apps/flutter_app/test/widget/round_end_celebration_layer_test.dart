import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/game/presentation/widgets/round_end_celebration_layer.dart';

class _StateProbe extends StatefulWidget {
  const _StateProbe({super.key});

  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 40, height: 40);
}

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RoundEndCelebrationLayer', () {
    testWidgets('renders child when winnerPlayerIds is empty', (tester) async {
      await tester.pumpWidget(host(
        const RoundEndCelebrationLayer(
          winnerPlayerIds: {},
          seatKeys: {},
          child: Text('game-body'),
        ),
      ));
      expect(find.text('game-body'), findsOneWidget);
    });

    testWidgets('renders child when winnerPlayerIds is non-empty',
        (tester) async {
      await tester.pumpWidget(host(
        const RoundEndCelebrationLayer(
          winnerPlayerIds: {'p1'},
          seatKeys: {},
          child: Text('game-body'),
        ),
      ));
      expect(find.text('game-body'), findsOneWidget);
    });

    // REGRESSION TEST. The old build branched: when no winners, returned
    // `child` directly; when winners, wrapped in Stack > Positioned.fill >
    // child. The shape change unmounted+remounted the entire game body
    // (including CardHand) on every round-end transition, destroying the
    // staggered-deal State so cards re-played their entry animation —
    // visible as jitter at round boundaries.
    testWidgets('preserves child State when winnerPlayerIds toggles',
        (tester) async {
      final probeKey = GlobalKey<_StateProbeState>();

      await tester.pumpWidget(host(
        RoundEndCelebrationLayer(
          winnerPlayerIds: const {},
          seatKeys: const {},
          child: _StateProbe(key: probeKey),
        ),
      ));
      final originalState = probeKey.currentState;
      expect(originalState, isNotNull);

      // empty → non-empty (round just ended)
      await tester.pumpWidget(host(
        RoundEndCelebrationLayer(
          winnerPlayerIds: const {'winner1'},
          seatKeys: const {},
          child: _StateProbe(key: probeKey),
        ),
      ));
      await tester.pump();
      expect(probeKey.currentState, same(originalState),
          reason:
              'Child State must persist when winnerPlayerIds becomes non-empty');

      // non-empty → empty (next round started)
      await tester.pumpWidget(host(
        RoundEndCelebrationLayer(
          winnerPlayerIds: const {},
          seatKeys: const {},
          child: _StateProbe(key: probeKey),
        ),
      ));
      await tester.pump();
      expect(probeKey.currentState, same(originalState),
          reason:
              'Child State must persist when winnerPlayerIds becomes empty again');
    });
  });
}
