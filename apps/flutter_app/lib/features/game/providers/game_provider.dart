import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

import '../../../core/services/supabase_service.dart';

final gameStateProvider =
    StateNotifierProvider<GameNotifier, GameState?>((ref) {
  return GameNotifier(ref.watch(supabaseServiceProvider));
});

class GameNotifier extends StateNotifier<GameState?> {
  final SupabaseService _supabase;
  String? _gameType;

  GameNotifier(this._supabase) : super(null);

  /// Set the active game type for state deserialization.
  void setGameType(String gameType) {
    _gameType = gameType;
  }

  /// Subscribe to real-time game state updates for a room.
  Future<void> subscribeToGame({required String roomId}) async {
    print('[GameNotifier] subscribeToGame roomId=$roomId gameType=$_gameType');
    _supabase.subscribeToGameState(
      roomId: roomId,
      onUpdate: (data) {
        print('[GameNotifier] onUpdate received: gameType=$_gameType, dataKeys=${(data as Map).keys.toList()}');
        if (_gameType == null) return;
        final stateData = data['state_data'] as Map<String, dynamic>?;
        if (stateData == null) {
          print('[GameNotifier] state_data is null');
          return;
        }
        final newState = deserializeGameState(_gameType!, stateData);
        print('[GameNotifier] deserialized state: ${newState != null ? 'OK' : 'NULL'}');
        if (newState != null) {
          state = newState;
        }
      },
    );
  }

  /// Send a move to the server.
  Future<void> sendMove({
    required String roomId,
    required dynamic move,
  }) async {
    await _supabase.sendMove(roomId: roomId, move: move);
  }

  /// Directly update the game state (used by tests and local state injection).
  void updateState(GameState newState) {
    state = newState;
  }

  /// Clear the game state (e.g., on game exit).
  void clearState() {
    state = null;
    _gameType = null;
  }
}

/// Deserialize raw JSON state_data into the appropriate typed GameState.
GameState? deserializeGameState(String gameType, Map<String, dynamic> json) {
  try {
    switch (gameType) {
      case 'twenty_nine':
        return TwentyNineState.fromJson(json);
      case 'oh_hell':
        return OhHellState.fromJson(json);
      // TODO: Add fromJson for other game types as they are implemented
      default:
        return null;
    }
  } catch (e, st) {
    // Log deserialization errors for debugging
    print('[deserializeGameState] ERROR for $gameType: $e');
    print('[deserializeGameState] Stack: $st');
    return null;
  }
}

class BidMoveDto {
  final String playerId;
  final int bidValue;

  const BidMoveDto({required this.playerId, required this.bidValue});

  Map<String, dynamic> toJson() => {
        'type': 'bid',
        'player_id': playerId,
        'bid_value': bidValue,
      };
}
