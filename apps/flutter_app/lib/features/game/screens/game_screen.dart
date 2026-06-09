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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(gameStateProvider.notifier);
      final gameType = ref.read(gameTypeProvider);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final gameType = ref.watch(gameTypeProvider);

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
