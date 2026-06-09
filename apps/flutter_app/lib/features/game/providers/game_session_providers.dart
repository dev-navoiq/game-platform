import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../../../core/di/providers.dart';
import '../../lobby/models/room_member.dart';
import 'game_provider.dart';

/// Tracks the active game type (e.g., 'oh_hell', 'twenty_nine', 'chess').
final gameTypeProvider = StateProvider<String?>((ref) => null);

/// Player identity lookup for the active room — populated by the room
/// screen before navigating into the game so the seat avatars can show
/// real display names + a human/bot indicator instead of falling back to
/// "Bot 1". Keyed by playerId.
final roomMembersProvider =
    StateProvider<Map<String, RoomMember>>((ref) => const {});

/// Currently selected card in hand (card games).
final selectedCardProvider = StateProvider<PlayingCard?>((ref) => null);

/// A card the user tapped *before* their turn. CardHand auto-dispatches it
/// when the turn arrives. Cleared whenever a move is sent or the hand
/// changes shape (new deal, card removed).
final queuedCardProvider = StateProvider<PlayingCard?>((ref) => null);

/// Currently selected board position (board games).
final selectedPositionProvider = StateProvider<dynamic>((ref) => null);

/// Whether it is the local player's turn.
final isMyTurnProvider = Provider<bool>((ref) {
  final state = ref.watch(gameStateProvider);
  final currentUser = ref.watch(currentUserProvider);
  if (state == null || currentUser == null) return false;
  return state.currentPlayerId == currentUser.id;
});

/// Whether the local player is spectating (not a participant).
final isSpectatorProvider = Provider<bool>((ref) {
  final state = ref.watch(gameStateProvider);
  final currentUser = ref.watch(currentUserProvider);
  if (state == null || currentUser == null) return true;
  // Check game-specific player lists
  final userId = currentUser.id;
  return !_isPlayerInGame(state, userId);
});

bool _isPlayerInGame(GameState state, String userId) {
  // Use dynamic property access for different game state types
  try {
    final dynamic dynState = state;
    // Card games have playerOrder
    if (dynState.playerOrder is List<String>) {
      return (dynState.playerOrder as List<String>).contains(userId);
    }
  } catch (_) {}
  try {
    final dynamic dynState = state;
    // Board games have playerIds
    if (dynState.playerIds is List<String>) {
      return (dynState.playerIds as List<String>).contains(userId);
    }
  } catch (_) {}
  return false;
}
