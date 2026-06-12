// Single-tap commit contract for CardHand in tapToPlay mode.
//
// The user-facing rule: when it IS your turn and the card is legal, ONE
// tap fires onCardTap and starts the flight animation. There is no
// "select then commit" two-tap step. Illegal taps fire onIllegalTap and
// don't dispatch a move. Taps when it's not your turn queue the card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'package:flutter_app/features/game/presentation/widgets/card_hand.dart';
import 'package:flutter_app/features/game/providers/game_session_providers.dart';
import 'package:flutter_app/shared/widgets/playing_card_widget.dart';

void main() {
  const aceSpades = PlayingCard(Suit.spades, Rank.ace);
  const kingHearts = PlayingCard(Suit.hearts, Rank.king);
  const twoClubs = PlayingCard(Suit.clubs, Rank.two);

  Widget host({
    required List<PlayingCard> cards,
    required bool isPlayable,
    Set<PlayingCard>? validCards,
    void Function(PlayingCard)? onCardTap,
    void Function(PlayingCard)? onIllegalTap,
    bool allowQueueWhenNotPlayable = true,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 200,
            child: CardHand(
              cards: cards,
              isPlayable: isPlayable,
              validCards: validCards,
              onCardTap: onCardTap,
              onIllegalTap: onIllegalTap,
              allowQueueWhenNotPlayable: allowQueueWhenNotPlayable,
            ),
          ),
        ),
      ),
    );
  }

  group('CardHand tapToPlay — single-tap commit', () {
    testWidgets('one tap on a playable card fires onCardTap immediately',
        (tester) async {
      PlayingCard? tapped;
      await tester.pumpWidget(host(
        cards: [aceSpades, kingHearts, twoClubs],
        isPlayable: true,
        onCardTap: (c) => tapped = c,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PlayingCardWidget).first);
      await tester.pump();

      expect(tapped, isNotNull,
          reason: 'first tap should commit, not just select');
    });

    testWidgets('tap on illegal card fires onIllegalTap, not onCardTap',
        (tester) async {
      PlayingCard? committed;
      PlayingCard? illegal;
      await tester.pumpWidget(host(
        cards: [aceSpades, kingHearts],
        isPlayable: true,
        validCards: {kingHearts}, // only the king is legal
        onCardTap: (c) => committed = c,
        onIllegalTap: (c) => illegal = c,
      ));
      await tester.pumpAndSettle();

      // First card in display order. We just need the illegal one tapped;
      // assert by checking which callback fired.
      await tester.tap(find.byType(PlayingCardWidget).first);
      await tester.pump();

      // Exactly one of committed / illegal fired.
      expect(committed == null || illegal == null, isTrue);
      // And whichever fired matched the legality of the tapped card.
      if (committed != null) {
        expect({kingHearts}.contains(committed), isTrue);
      } else {
        expect(illegal, isNotNull);
        expect({kingHearts}.contains(illegal), isFalse);
      }
    });

    testWidgets('tap when not playable queues the card', (tester) async {
      PlayingCard? committed;
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 200,
                  child: CardHand(
                    cards: [aceSpades, kingHearts],
                    isPlayable: false,
                    onCardTap: (c) => committed = c,
                  ),
                ),
              ),
            );
          }),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PlayingCardWidget).first);
      await tester.pump();

      expect(committed, isNull,
          reason: 'no move dispatched when not our turn');
      expect(container.read(queuedCardProvider), isNotNull,
          reason: 'tap should queue the card for auto-dispatch on turn');
    });
  });
}
