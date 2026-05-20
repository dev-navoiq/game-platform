import 'package:equatable/equatable.dart';

/// A quick emoji reaction in a game room.
///
/// Maps to the `quick_reactions` table in the database.
class Reaction extends Equatable {
  final String id;
  final String roomId;
  final String userId;
  final String reaction;
  final DateTime createdAt;

  const Reaction({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.reaction,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, roomId, userId, reaction, createdAt];

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      reaction: json['reaction'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'user_id': userId,
        'reaction': reaction,
      };
}
