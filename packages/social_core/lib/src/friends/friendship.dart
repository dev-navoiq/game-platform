import 'package:equatable/equatable.dart';

/// Status of a friendship.
enum FriendshipStatus { pending, accepted, declined, blocked }

/// A friendship relationship between two users.
///
/// Maps to the `friendships` table in the database.
class Friendship extends Equatable {
  final String id;
  final String userId;
  final String friendId;
  final String? friendName;
  final String? friendAvatarUrl;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    this.friendName,
    this.friendAvatarUrl,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, userId, friendId, status, createdAt];

  factory Friendship.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    return Friendship(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      friendId: json['friend_id'] as String,
      status: FriendshipStatus.values.byName(statusStr),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'friend_id': friendId,
        'status': status.name,
      };
}
