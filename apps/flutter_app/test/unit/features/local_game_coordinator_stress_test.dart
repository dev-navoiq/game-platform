import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_ludo/game_ludo.dart';

import 'package:flutter_app/features/game/local/local_game_coordinator.dart';

/// Seed-sweep stress test that emulates LudoGameScreen's *exact* interaction
/// protocol (not "any valid move"): tap dice only when lastRoll is null, tap
/// a movable token otherwise, and auto-pass only when pass is the sole valid
/// move — guarded by `_autoPassedForTurn != turnNumber` just like the screen.
/// Any divergence between what the screen would do and what the engine needs
/// shows up here as a stall, with a full state dump for diagnosis.
void main() {
  test('screen-protocol seed sweep: every practice game terminates', () async {
    const humanId = 'human-player';

    for (var seed = 0; seed < 300; seed++) {
      final states = <LudoState>[];
      final botCount = seed % 3 + 1;
      final coordinator = LocalGameCoordinator.ludo(
        roomId: 'local-stress-$seed',
        humanPlayerId: humanId,
        botCount: botCount,
        publish: (s) => states.add(s as LudoState),
        random: Random(seed),
        botThinkDelayOverride: Duration.zero,
      );
      coordinator.start();

      final probe = LudoRules();
      final humanRng = Random(seed ^ 0x5f3759df);
      var autoPassedForTurn = -1; // mirrors LudoGameScreen._autoPassedForTurn
      var stall = 0;

      String dump(LudoState s) => 'seed=$seed bots=$botCount '
          'turn=${s.turnNumber} current=${s.currentPlayerId} '
          'lastRoll=${s.lastRoll} canRollAgain=${s.canRollAgain} '
          'sixes=${s.consecutiveSixes} finished=${s.finishedPlayers} '
          'phase=${s.phase} autoPassGuard=$autoPassedForTurn';

      while (!states.last.isGameOver) {
        final s = states.last;
        final before = states.length;

        if (s.currentPlayerId == humanId) {
          final valid = probe.getValidMoves(s, humanId);
          expect(valid, isNotEmpty,
              reason: 'engine offered the human nothing: ${dump(s)}');
          final mustPass = valid.length == 1 && valid.first is LudoPass;
          if (mustPass) {
            // The screen only auto-passes once per turnNumber.
            if (autoPassedForTurn != s.turnNumber) {
              autoPassedForTurn = s.turnNumber;
              await coordinator
                  .handleWireMove({'type': 'pass', 'player_id': humanId});
            }
          } else if (s.lastRoll == null) {
            await coordinator
                .handleWireMove({'type': 'roll', 'player_id': humanId});
          } else {
            final tokenMoves = valid.whereType<LudoMoveToken>().toList();
            expect(tokenMoves, isNotEmpty,
                reason: 'rolled but no token moves and not mustPass: '
                    '${dump(s)}');
            final pick = tokenMoves[humanRng.nextInt(tokenMoves.length)];
            await coordinator.handleWireMove({
              'type': 'move',
              'player_id': humanId,
              'token_id': pick.tokenId,
            });
          }
        } else {
          // Bot turn: yield so the zero-delay bot timer can fire.
          await Future<void>.delayed(Duration.zero);
        }

        stall = states.length == before ? stall + 1 : 0;
        if (stall > 500) {
          fail('practice game stalled: ${dump(states.last)}');
        }
      }

      coordinator.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
