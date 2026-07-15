import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:flutter_app/features/game/local/local_game_coordinator.dart';
import 'package:flutter_app/features/game/presentation/widgets/game_over_dialog.dart';
import 'package:flutter_app/features/game/presentation/widgets/ludo_dice_widget.dart';
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/features/game/providers/game_session_providers.dart';
import 'package:flutter_app/features/game/screens/game_screen.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

/// End-to-end practice game through the REAL widget tree: GameScreen →
/// LudoGameScreen with a live LocalGameCoordinator. The human's rolls go
/// through actual dice taps (exercising _rollDice's 600ms delay), token
/// moves through sendMove, and must-pass turns are deliberately NOT sent —
/// the screen's auto-pass has to handle them, exactly like on device.
void main() {
  testWidgets('practice vs bots runs to game over through the real UI',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const humanId = 'human-player';

    // Phone-sized portrait surface — the default 800x600 landscape canvas
    // triggers cosmetic RenderFlex overflows unrelated to game flow.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // The WIP ludo HUD overflows by a few px on some turns (cosmetic, known).
    // Swallow ONLY RenderFlex overflow reports; anything else still fails.
    final defaultOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('RenderFlex overflowed')) {
        return;
      }
      defaultOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = defaultOnError);

    for (final seed in [1, 7, 42]) {
      const roomId = 'local-widget-game';
      final notifier = GameNotifier(MockSupabaseService());
      notifier.setGameType('ludo');

      final coordinator = LocalGameCoordinator.ludo(
        roomId: roomId,
        humanPlayerId: humanId,
        botCount: 1, // 2-player game: ends when the first player finishes
        publish: notifier.updateState,
        random: Random(seed),
        botThinkDelayOverride: const Duration(milliseconds: 100),
      );
      notifier.attachLocalSession(coordinator);
      coordinator.start();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          gameStateProvider.overrideWith((ref) => notifier),
          gameTypeProvider.overrideWith((ref) => 'ludo'),
        ],
        child: const MaterialApp(home: GameScreen(roomId: roomId)),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      final probe = LudoRules();
      final rng = Random(seed ^ 0x9e3779b9);

      LudoState state() => notifier.state! as LudoState;
      String dump() {
        final s = state();
        return 'seed=$seed turn=${s.turnNumber} current=${s.currentPlayerId} '
            'lastRoll=${s.lastRoll} canRollAgain=${s.canRollAgain} '
            'finished=${s.finishedPlayers} phase=${s.phase}';
      }

      var stall = 0;
      var lastSignature = '';
      var safety = 0;
      while (!state().isGameOver && safety++ < 4000) {
        final s = state();
        if (s.currentPlayerId == humanId) {
          final valid = probe.getValidMoves(s, humanId);
          final mustPass =
              valid.length == 1 && valid.first is LudoPass;
          if (mustPass) {
            // Screen must auto-pass; we only give it frames.
            await tester.pump(const Duration(milliseconds: 100));
          } else if (s.lastRoll == null) {
            expect(find.byType(LudoDiceWidget), findsOneWidget,
                reason: 'dice must be on screen on the human turn: ${dump()}');
            await tester.tap(find.byType(LudoDiceWidget),
                warnIfMissed: false);
            // _rollDice waits 600ms before sending the wire move.
            await tester.pump(const Duration(milliseconds: 700));
          } else {
            final tokenMoves = valid.whereType<LudoMoveToken>().toList();
            final pick = tokenMoves[rng.nextInt(tokenMoves.length)];
            await notifier.sendMove(roomId: roomId, move: {
              'type': 'move',
              'player_id': humanId,
              'token_id': pick.tokenId,
            });
            await tester.pump(const Duration(milliseconds: 50));
          }
        } else {
          // Bot turn — advance fake time so the coordinator timer fires.
          await tester.pump(const Duration(milliseconds: 150));
        }

        final sig = dump();
        stall = sig == lastSignature ? stall + 1 : 0;
        lastSignature = sig;
        if (stall > 300) {
          fail('practice game froze in the real UI: $sig');
        }
      }

      expect(state().isGameOver, isTrue,
          reason: 'game must reach game over: ${dump()}');

      // Game-over overlay (with its ad hook) must mount without exploding.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GameOverDialog), findsOneWidget,
          reason: 'game over UI must appear: ${dump()}');

      // Unmount between seeds; GameScreen.dispose clears game providers.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
