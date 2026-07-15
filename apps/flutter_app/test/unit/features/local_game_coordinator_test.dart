import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_ludo/game_ludo.dart';

import 'package:flutter_app/features/game/local/local_game_coordinator.dart';
import 'package:flutter_app/features/game/local/local_game_session.dart';

/// These tests intentionally never call Supabase.initialize(): any code path
/// that touched the network (Supabase client, edge functions, realtime)
/// would throw immediately. Driving a complete game through the coordinator
/// therefore proves the practice flow is fully on-device.
void main() {
  Map<String, dynamic> wireFor(LudoMove move) => switch (move) {
        LudoRollDice() => {'type': 'roll', 'player_id': move.playerId},
        LudoMoveToken() => {
            'type': 'move',
            'player_id': move.playerId,
            'token_id': move.tokenId,
          },
        LudoPass() => {'type': 'pass', 'player_id': move.playerId},
      };

  test('local room ids are recognized and cannot collide with UUIDs', () {
    expect(LocalGameSession.isLocalRoomId('local-1234'), isTrue);
    expect(
      LocalGameSession.isLocalRoomId('6a1f4c9e-0000-0000-0000-000000000000'),
      isFalse,
    );
  });

  test(
      'full local Ludo game: 1 scripted human + 3 bots runs to completion '
      'with no network', () async {
    const humanId = 'human-player';
    final states = <LudoState>[];

    final coordinator = LocalGameCoordinator.ludo(
      roomId: 'local-test-room',
      humanPlayerId: humanId,
      botCount: 3,
      publish: (s) => states.add(s as LudoState),
      random: Random(42), // deterministic dice + bot behaviour
      botThinkDelayOverride: Duration.zero, // instant bot turns for the test
    );

    coordinator.start();
    expect(states, hasLength(1));
    expect(states.first.playerIds, hasLength(4));
    expect(states.first.playerIds.first, humanId);
    expect(states.first.currentPlayerId, humanId,
        reason: 'human launched the game so the human is first to act');

    // A pure engine (fresh instance, unused Random) to enumerate the
    // human's legal moves. The human plays randomly — legality is what we
    // are testing, not skill.
    final probe = LudoRules();
    final humanRng = Random(7);

    var safety = 0;
    const maxIterations = 200000;
    while (!states.last.isGameOver && safety++ < maxIterations) {
      final current = states.last;
      if (current.currentPlayerId == humanId) {
        final moves = probe.getValidMoves(current, humanId);
        expect(moves, isNotEmpty,
            reason: 'engine must always offer the current player a move');
        final choice = moves[humanRng.nextInt(moves.length)];
        final before = states.length;
        // Same wire format LudoGameScreen sends through sendMove.
        await coordinator.handleWireMove(wireFor(choice));
        expect(states.length, greaterThan(before),
            reason: 'a legal human move must be applied and published');
      } else {
        // Bot turn — yield to the event loop so the zero-delay bot timer
        // fires (roll, then token move / pass).
        await Future<void>.delayed(Duration.zero);
      }
    }

    expect(safety, lessThan(maxIterations),
        reason: 'game must terminate — possible infinite loop');

    final last = states.last;
    expect(last.isGameOver, isTrue);
    expect(last.phase, GamePhase.gameEnd);
    expect(last.winnerId, isNotNull);
    expect(last.finishedPlayers, hasLength(4),
        reason: 'every seat gets a placement at game end');
    expect(last.finishedPlayers.first, last.winnerId);

    // No further bot activity after the game ends.
    final countAtEnd = states.length;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(states.length, countAtEnd);

    coordinator.dispose();
  });

  test('invalid or undecodable wire moves are ignored, not applied', () async {
    const humanId = 'human-player';
    final states = <LudoState>[];

    final coordinator = LocalGameCoordinator.ludo(
      roomId: 'local-test-room-2',
      humanPlayerId: humanId,
      botCount: 1,
      publish: (s) => states.add(s as LudoState),
      random: Random(1),
      botThinkDelayOverride: const Duration(days: 1), // bots effectively frozen
    );
    coordinator.start();
    final published = states.length;

    // Moving a token before rolling is undecodable (no lastRoll to derive
    // steps from) — must be dropped silently.
    await coordinator
        .handleWireMove({'type': 'move', 'player_id': humanId, 'token_id': 'x'});
    // Unknown move type — dropped.
    await coordinator.handleWireMove({'type': 'teleport', 'player_id': humanId});
    // Out-of-turn roll by the bot's id while it is the human's turn — the
    // engine rejects it and nothing is published.
    await coordinator
        .handleWireMove({'type': 'roll', 'player_id': 'local-bot-1'});

    expect(states.length, published, reason: 'no state may be published');
    coordinator.dispose();
  });

  test('dispose stops the bot loop', () async {
    const humanId = 'human-player';
    final states = <LudoState>[];

    final coordinator = LocalGameCoordinator.ludo(
      roomId: 'local-test-room-3',
      humanPlayerId: humanId,
      botCount: 1,
      publish: (s) => states.add(s as LudoState),
      random: Random(3),
      botThinkDelayOverride: Duration.zero,
    );
    coordinator.start();

    // Human rolls, then immediately leaves (screen dispose → coordinator
    // dispose). Any scheduled bot timer must not fire afterwards.
    await coordinator.handleWireMove({'type': 'roll', 'player_id': humanId});
    coordinator.dispose();
    final countAtDispose = states.length;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(states.length, countAtDispose);
  });
}
