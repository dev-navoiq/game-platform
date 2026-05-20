import 'voice_state.dart';

/// Abstract interface for voice chat.
///
/// Implementations handle the actual voice backend (e.g. LiveKit).
abstract class VoiceService {
  /// Stream of voice state changes.
  Stream<VoiceState> get stateStream;

  /// Current voice state snapshot.
  VoiceState get currentState;

  /// Connect to voice chat in a room.
  Future<void> connect({
    required String roomId,
    required String userId,
  });

  /// Disconnect from voice chat.
  Future<void> disconnect();

  /// Toggle local microphone mute.
  Future<void> toggleMute();

  /// Set mute state explicitly.
  Future<void> setMuted(bool muted);

  /// Clean up resources.
  Future<void> dispose();
}
