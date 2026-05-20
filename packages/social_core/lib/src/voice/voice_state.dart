import 'package:equatable/equatable.dart';

/// Connection status for voice chat.
enum VoiceConnectionStatus { disconnected, connecting, connected, error }

/// Immutable state of the voice chat system.
class VoiceState extends Equatable {
  final VoiceConnectionStatus status;
  final bool isMuted;
  final bool isDeafened;
  final Map<String, bool> speakingStates;

  const VoiceState({
    this.status = VoiceConnectionStatus.disconnected,
    this.isMuted = false,
    this.isDeafened = false,
    this.speakingStates = const {},
  });

  const VoiceState.initial()
      : status = VoiceConnectionStatus.disconnected,
        isMuted = false,
        isDeafened = false,
        speakingStates = const {};

  bool get isConnected => status == VoiceConnectionStatus.connected;

  @override
  List<Object?> get props => [status, isMuted, isDeafened, speakingStates];

  VoiceState copyWith({
    VoiceConnectionStatus? status,
    bool? isMuted,
    bool? isDeafened,
    Map<String, bool>? speakingStates,
  }) {
    return VoiceState(
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      speakingStates: speakingStates ?? this.speakingStates,
    );
  }
}

/// A participant in a voice chat session.
class VoiceParticipant extends Equatable {
  final String id;
  final String name;
  final bool isMuted;
  final bool isSpeaking;
  final bool isLocal;

  const VoiceParticipant({
    required this.id,
    required this.name,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isLocal = false,
  });

  @override
  List<Object?> get props => [id, name, isMuted, isSpeaking, isLocal];
}
