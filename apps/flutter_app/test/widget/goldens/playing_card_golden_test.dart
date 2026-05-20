import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_app/shared/widgets/playing_card_widget.dart';

void main() {
  group('PlayingCardWidget Golden Tests', () {
    testGoldens('card faces render correctly — grid', (tester) async {
      final builder = GoldenBuilder.grid(
        columns: 4,
        widthToHeightRatio: 0.66,
      )
        ..addScenario(
            'Ace of Hearts', const PlayingCardWidget(suit: 'hearts', rank: 'A'))
        ..addScenario(
            'King of Spades', const PlayingCardWidget(suit: 'spades', rank: 'K'))
        ..addScenario(
            'Queen of Diamonds',
            const PlayingCardWidget(suit: 'diamonds', rank: 'Q'))
        ..addScenario(
            'Jack of Clubs', const PlayingCardWidget(suit: 'clubs', rank: 'J'))
        ..addScenario(
            'Ten of Hearts', const PlayingCardWidget(suit: 'hearts', rank: '10'))
        ..addScenario('Card Back',
            const PlayingCardWidget(suit: 'hearts', rank: 'A', isFaceDown: true))
        ..addScenario(
            'Selected Card',
            const PlayingCardWidget(
                suit: 'spades', rank: 'A', isSelected: true))
        ..addScenario(
            'Disabled Card',
            const PlayingCardWidget(
                suit: 'clubs', rank: '7', isPlayable: false));

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(800, 600),
      );

      await screenMatchesGolden(tester, 'playing_cards_grid');
    });

    testGoldens('card skins render correctly', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
            'Classic Skin',
            const PlayingCardWidget(
                suit: 'hearts', rank: 'A', skinId: 'classic'))
        ..addScenario(
            'Modern Skin',
            const PlayingCardWidget(
                suit: 'hearts', rank: 'A', skinId: 'modern'))
        ..addScenario(
            'Neon Skin',
            const PlayingCardWidget(suit: 'hearts', rank: 'A', skinId: 'neon'));

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(300, 600),
      );

      await screenMatchesGolden(tester, 'card_skins');
    });
  });
}
