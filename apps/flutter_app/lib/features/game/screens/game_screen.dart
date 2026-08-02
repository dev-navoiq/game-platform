import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_bridge/game_bridge.dart';
import 'package:game_chess/game_chess.dart';
import 'package:game_hearts/game_hearts.dart';
import 'package:game_ludo/game_ludo.dart';
import 'package:game_oh_hell/game_oh_hell.dart';
import 'package:game_sequence/game_sequence.dart';
import 'package:game_spades/game_spades.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/felt_background.dart';
import '../presentation/screens/bridge_game_screen.dart';
import '../presentation/screens/chess_game_screen.dart';
import '../presentation/screens/hearts_game_screen.dart';
import '../presentation/screens/ludo_game_screen.dart';
import '../presentation/screens/oh_hell_game_screen.dart';
import '../presentation/screens/sequence_game_screen.dart';
import '../presentation/screens/spades_game_screen.dart';
import '../presentation/screens/twenty_nine_game_screen.dart';
import '../presentation/screens/unsupported_game_screen.dart';
import '../providers/bot_move_controller.dart';
import '../providers/game_provider.dart';
import '../providers/game_session_providers.dart';

/// Dispatch shell that routes to game-specific screens based on [gameTypeProvider].
///
/// Handles loading/error states and delegates rendering to the appropriate
/// game screen widget once state is available.
class GameScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _timeoutTimer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to realtime game state updates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Entering a DIFFERENT room while the previous game screen never
      // disposed (back-to-back games, sideways navigation) left the old
      // game's state in gameStateProvider — the new screen rendered the
      // previous game's podium and the whole flow dead-ended (#212).
      // If a stale room id is still published, drop the stale state first.
      final prevRoom = ref.read(currentRoomIdProvider);
      if (prevRoom != null && prevRoom != widget.roomId) {
        ref.invalidate(gameStateProvider);
      }
      // Publish the active room id so descendant widgets (GameActions etc.)
      // can read it without prop-drilling.
      ref.read(currentRoomIdProvider.notifier).state = widget.roomId;

      final notifier = ref.read(gameStateProvider.notifier);
      var gameType = ref.read(gameTypeProvider);
      // Always self-serve the room snapshot on /game/ entry. It carries both
      // the game type (needed on cold navigation — tournament "Play now",
      // push tap, deep link) and the seat identities. The member seed must
      // NOT be conditional on gameType: a stale non-null type (semifinal →
      // final re-entry, stacked push routes) used to skip it, leaving the
      // real human opponent rendered as "Bot 1" (#169).
      try {
        final snap = await ref
            .read(supabaseServiceProvider)
            .fetchRoomSnapshot(roomId: widget.roomId);
        gameType ??= snap.gameType;
        if (mounted) {
          ref.read(gameTypeProvider.notifier).state = gameType;
          ref.read(roomMembersProvider.notifier).state = {
            for (final m in snap.members) m.id: m,
          };
          ref.read(activeTournamentIdProvider.notifier).state =
              snap.tournamentId;
        }
      } catch (_) {
        // Snapshot fetch failed. If gameType was already known (lobby flow
        // seeded it, and the room screen seeded members) we can still play;
        // on a true cold nav it stays null and the timeout screen handles it.
      }
      if (!mounted) return;
      if (gameType != null) {
        notifier.setGameType(gameType);
      }
      notifier.subscribeToGame(roomId: widget.roomId);

      // Start bot move controller
      ref.read(botMoveControllerProvider).startWatching(roomId: widget.roomId);
    });
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && ref.read(gameStateProvider) == null) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();

    // Forfeit / back-button / route-pop all converge here. Clear all the
    // game-scoped state so a future room visit (or a quick "forfeit → back
    // to lobby → add bots → start") never inherits a stale game state, a
    // stale game type, or stale bot list. Before this, the host's
    // BotMoveController would re-fire on the previous game's state the
    // moment the new game screen mounted, dispatch a move against a dead
    // state, and the server would reject it (NOT_PLAYING / WRONG_PHASE)
    // — that's the "stuck after forfeit" loop.
    //
    // Guarded with try/catch because in widget tests the ConsumerElement
    // can be disposed before our State.dispose runs ("Cannot use ref
    // after the widget was disposed"); we don't want test teardown order
    // to mask real production code paths.
    try {
      ref.invalidate(gameStateProvider);
      ref.invalidate(gameTypeProvider);
      ref.read(roomBotsProvider.notifier).state = const [];
      // Clear seat identities too — a skipped/failed seed on the next mount
      // must not inherit the previous match's roster (#169).
      ref.read(roomMembersProvider.notifier).state = const {};
      ref.read(activeTournamentIdProvider.notifier).state = null;
      ref.read(currentRoomIdProvider.notifier).state = null;
    } catch (_) {
      // Test teardown — providers were already torn down. Nothing to do.
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameType = ref.watch(gameTypeProvider);

    // Surface bot-move rejections that the controller couldn't recover from
    // (anything but VERSION_CONFLICT, which it retries internally). Without
    // this hook a rejection leaves the table sitting in silence; with it,
    // the user gets a snackbar telling them the code (NOT_YOUR_TURN /
    // WRONG_PHASE / FORBIDDEN_BID) and can decide whether to forfeit.
    ref.listen<String?>(botMoveErrorProvider, (prev, next) {
      if (next == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next),
          duration: const Duration(seconds: 5),
        ),
      );
      // Clear so the same message doesn't replay on the next rebuild.
      ref.read(botMoveErrorProvider.notifier).state = null;
    });

    if (_timedOut && gameState == null) {
      return Scaffold(
        body: Center(
          child: Column(
            key: const Key('game-error'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load game'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (gameState == null) {
      // Match the felt table instead of flashing a bare white spinner, so the
      // jump from room → game reads as "dealing" rather than a blank load.
      return const Scaffold(
        backgroundColor: AppColors.feltDark,
        body: FeltBackground(
          child: Center(
            child: Column(
              key: Key('game-loading'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.accent),
                SizedBox(height: 20),
                Text(
                  'Setting up the table…',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    var localPlayerId = ref.watch(currentUserProvider)?.id ?? '';
    // Fallback: use the first player from state if no user is logged in (test support)
    if (localPlayerId.isEmpty) {
      localPlayerId = _firstPlayerId(gameState) ?? '';
    }

    return Scaffold(
      body: _buildGameScreen(gameType, gameState, localPlayerId),
    );
  }

  Widget _buildGameScreen(
      String? gameType, dynamic gameState, String localPlayerId) {
    switch (gameType) {
      case 'oh_hell':
        if (gameState is OhHellState) {
          return OhHellGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'twenty_nine':
        if (gameState is TwentyNineState) {
          return TwentyNineGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'hearts':
        if (gameState is HeartsState) {
          return HeartsGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'spades':
        if (gameState is SpadesState) {
          return SpadesGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'chess':
        if (gameState is ChessState) {
          return ChessGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'ludo':
        if (gameState is LudoState) {
          return LudoGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'sequence':
        if (gameState is SequenceState) {
          return SequenceGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'bridge':
        if (gameState is BridgeState) {
          return BridgeGameScreen(
            state: gameState,
            roomId: widget.roomId,
            localPlayerId: localPlayerId,
          );
        }
      case 'rummy':
        return UnsupportedGameScreen(
          gameType: gameType!,
          onLeave: () => Navigator.of(context).pop(),
        );
    }

    // Fallback: type-based dispatch without gameTypeProvider
    if (gameState is TwentyNineState) {
      return TwentyNineGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }
    if (gameState is OhHellState) {
      return OhHellGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }
    if (gameState is HeartsState) {
      return HeartsGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }
    if (gameState is SpadesState) {
      return SpadesGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }
    if (gameState is ChessState) {
      return ChessGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }
    if (gameState is LudoState) {
      return LudoGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }
    if (gameState is SequenceState) {
      return SequenceGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }
    if (gameState is BridgeState) {
      return BridgeGameScreen(
        state: gameState,
        roomId: widget.roomId,
        localPlayerId: localPlayerId,
      );
    }

    // Unknown game type
    return UnsupportedGameScreen(
      gameType: gameType ?? 'unknown',
      onLeave: () => Navigator.of(context).pop(),
    );
  }

  String? _firstPlayerId(dynamic state) {
    try {
      final dynamic s = state;
      if (s.playerOrder is List<String>) {
        final order = s.playerOrder as List<String>;
        if (order.isNotEmpty) return order.first;
      }
    } catch (_) {}
    try {
      final dynamic s = state;
      if (s.playerIds is List<String>) {
        final ids = s.playerIds as List<String>;
        if (ids.isNotEmpty) return ids.first;
      }
    } catch (_) {}
    return null;
  }
}
