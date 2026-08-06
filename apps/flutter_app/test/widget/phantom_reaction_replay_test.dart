// #221 — phantom reaction replay at round boundaries.
//
// The latest-reaction-by-player map only recomputes when a NEW event
// arrives, so its 5s freshness cutoff is evaluated then and the map stays
// "fresh" forever. Any remount of the bubble subtree (verdict pill swapping
// it out and back at round end, Ready clearing the pill) re-read the stale
// map and replayed the player's last reaction minutes later. PlayerNode now
// gates on freshness AT DISPLAY TIME.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_core/social_core.dart';

import 'package:flutter_app/features/game/presentation/widgets/player_node.dart';
import 'package:flutter_app/features/social/providers/social_providers.dart';
import 'package:flutter_app/shared/widgets/floating_chat_bubble.dart';

const _roomId = 'room-1';
const _playerId = 'player-1';

Reaction _reaction({required Duration age}) => Reaction(
      id: 'r1',
      roomId: _roomId,
      userId: _playerId,
      reaction: '👏',
      createdAt: DateTime.now().subtract(age),
    );

Widget _harness(Reaction reaction, {String? reactionEmote}) {
  return ProviderScope(
    overrides: [
      latestReactionByPlayerProvider.overrideWith(
        (ref, roomId) => {_playerId: reaction},
      ),
      latestChatByPlayerProvider.overrideWith(
        (ref, roomId) => const {},
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: PlayerNode(
          name: 'Tester',
          roomId: _roomId,
          playerId: _playerId,
          reactionEmote: reactionEmote,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('fresh reaction shows the bubble', (tester) async {
    await tester.pumpWidget(_harness(_reaction(age: Duration.zero)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FloatingChatBubble), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 8));
  });

  testWidgets('stale reaction renders nothing (phantom replay regression)',
      (tester) async {
    await tester
        .pumpWidget(_harness(_reaction(age: const Duration(seconds: 30))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FloatingChatBubble), findsNothing);
  });

  testWidgets(
      'round-boundary remount with a stale reaction stays silent — '
      'verdict pill swaps the subtree out and back', (tester) async {
    final stale = _reaction(age: const Duration(seconds: 30));

    // Round end: verdict pill visible, bubble subtree removed.
    await tester.pumpWidget(_harness(stale, reactionEmote: 'OH HELL'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FloatingChatBubble), findsNothing);

    // Ready tapped → pill clears → subtree remounts. Before the fix this
    // replayed the stale reaction.
    await tester.pumpWidget(_harness(stale));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FloatingChatBubble), findsNothing);
  });
}
