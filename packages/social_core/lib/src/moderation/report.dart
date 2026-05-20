import 'package:equatable/equatable.dart';

/// Type of moderation action recorded in the log.
enum ModerationAction { mute, unmute, kick, ban, warn }

/// A moderation log entry.
///
/// Maps to the `moderation_log` table in the database.
class ModerationEntry extends Equatable {
  final String id;
  final String roomId;
  final String? moderatorId;
  final String targetId;
  final ModerationAction action;
  final String? reason;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const ModerationEntry({
    required this.id,
    required this.roomId,
    this.moderatorId,
    required this.targetId,
    required this.action,
    this.reason,
    this.expiresAt,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        roomId,
        moderatorId,
        targetId,
        action,
        reason,
        expiresAt,
        createdAt,
      ];

  factory ModerationEntry.fromJson(Map<String, dynamic> json) {
    return ModerationEntry(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      moderatorId: json['moderator_id'] as String?,
      targetId: json['target_id'] as String,
      action: ModerationAction.values.byName(json['action'] as String),
      reason: json['reason'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
