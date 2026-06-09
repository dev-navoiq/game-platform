import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_bridge/game_bridge.dart';

import 'package:flutter_app/features/game/presentation/widgets/bridge_contract_banner.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('BridgeContractBanner', () {
    testWidgets('renders 3NT by N (doubled, NS vulnerable)', (tester) async {
      const contract = BridgeContract(
        level: 3,
        denomination: BridgeDenomination.noTrump,
        doubleStatus: BridgeDoubleStatus.doubled,
        declarerId: 'north',
        declarerSeat: 0,
      );

      await tester.pumpWidget(wrap(const BridgeContractBanner(
        contract: contract,
        vulnerability: Vulnerability.ns,
        declarerTricks: 7,
      )));

      expect(find.byKey(const Key('bridge-contract-banner')), findsOneWidget);
      // Level + denomination compound text "3NT"
      expect(find.text('3NT'), findsOneWidget);
      // Declarer label
      expect(find.text('by N'), findsOneWidget);
      // Doubled tag
      expect(find.text('X'), findsOneWidget);
      // VUL tag (NS vulnerable, declarer is NS)
      expect(find.text('VUL'), findsOneWidget);
      // Tricks line: 7/9 (3NT requires 6+3=9)
      expect(find.text('7/9 tricks'), findsOneWidget);
    });

    testWidgets('undoubled contract has no double tag', (tester) async {
      const contract = BridgeContract(
        level: 4,
        denomination: BridgeDenomination.hearts,
        doubleStatus: BridgeDoubleStatus.undoubled,
        declarerId: 'east',
        declarerSeat: 1,
      );

      await tester.pumpWidget(wrap(const BridgeContractBanner(
        contract: contract,
        vulnerability: Vulnerability.none,
        declarerTricks: 0,
      )));

      expect(find.text('4♥'), findsOneWidget);
      expect(find.text('by E'), findsOneWidget);
      // No double or redouble tags
      expect(find.text('X'), findsNothing);
      expect(find.text('XX'), findsNothing);
      // Not vulnerable
      expect(find.text('VUL'), findsNothing);
      // 4♥ requires 10 tricks; declarer has taken 0
      expect(find.text('0/10 tricks'), findsOneWidget);
    });

    testWidgets('redoubled contract shows XX', (tester) async {
      const contract = BridgeContract(
        level: 2,
        denomination: BridgeDenomination.spades,
        doubleStatus: BridgeDoubleStatus.redoubled,
        declarerId: 'south',
        declarerSeat: 2,
      );

      await tester.pumpWidget(wrap(const BridgeContractBanner(
        contract: contract,
        vulnerability: Vulnerability.both,
        declarerTricks: 5,
      )));

      expect(find.text('2♠'), findsOneWidget);
      expect(find.text('by S'), findsOneWidget);
      expect(find.text('XX'), findsOneWidget);
      expect(find.text('VUL'), findsOneWidget);
    });
  });
}
