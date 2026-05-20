import 'dart:async';

import 'voice_service.dart';
import 'voice_state.dart';

/// Stub implementation of [VoiceService] that returns disconnected state.
///
/// Used until a real voice backend (e.g. LiveKit) is integrated.
class StubVoiceService implements VoiceService {
  final _controller = StreamController<VoiceState>.broadcast();
  VoiceState _state = const VoiceState.initial();

  @override
  Stream<VoiceState> get stateStream => _controller.stream;

  @override
  VoiceState get currentState => _state;

  @override
  Future<void> connect({
    required String roomId,
    required String userId,
  }) async {
    // No-op: voice chat not yet available
  }

  @override
  Future<void> disconnect() async {
    // No-op
  }

  @override
  Future<void> toggleMute() async {
    _state = _state.copyWith(isMuted: !_state.isMuted);
    _controller.add(_state);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _state = _state.copyWith(isMuted: muted);
    _controller.add(_state);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
