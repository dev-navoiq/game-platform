import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.watch(supabaseServiceProvider));
});

/// Thin wrapper over [SupabaseService] for game-specific data operations.
class GameRepository {
  final SupabaseService _supabase;

  GameRepository(this._supabase);

  /// Subscribe to real-time game state updates.
  void subscribeToGameState({
    required String roomId,
    required void Function(Map<String, dynamic> data) onUpdate,
  }) {
    _supabase.subscribeToGameState(roomId: roomId, onUpdate: onUpdate);
  }

  /// Send a game move to the server for validation and application.
  Future<void> sendMove({
    required String roomId,
    required dynamic move,
  }) async {
    await _supabase.sendMove(roomId: roomId, move: move);
  }

  /// Send a chat message in the game room.
  Future<void> sendChatMessage({
    required String roomId,
    required String message,
    required String senderId,
  }) async {
    await _supabase.insertChatMessage(
      roomId: roomId,
      message: message,
      senderId: senderId,
    );
  }

  /// Subscribe to chat messages.
  void subscribeToChatMessages({
    required String roomId,
    required void Function(Map<String, dynamic> message) onMessage,
  }) {
    _supabase.subscribeToRoomMessages(roomId: roomId, onMessage: onMessage);
  }
}
