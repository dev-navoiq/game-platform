import 'package:equatable/equatable.dart';

/// Result of attempting to initiate or cast a mute vote.
enum MuteVoteResult {
  success,
  cannotVoteSelf,
  onCooldown,
  alreadyMuted,
  voteAlreadyActive,
  error,
}

/// A single mute vote record.
///
/// Maps to the `mute_votes` table in the database.
class MuteVote extends Equatable {
  final String id;
  final String roomId;
  final String voterId;
  final String targetId;
  final DateTime createdAt;

  const MuteVote({
    required this.id,
    required this.roomId,
    required this.voterId,
    required this.targetId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, roomId, voterId, targetId, createdAt];

  factory MuteVote.fromJson(Map<String, dynamic> json) {
    return MuteVote(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      voterId: json['voter_id'] as String,
      targetId: json['target_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'voter_id': voterId,
        'target_id': targetId,
        'created_at': createdAt.toIso8601String(),
      };
}
