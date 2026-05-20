import 'package:equatable/equatable.dart';

/// Activity status of a friend.
///
/// Named `FriendActivityType` to avoid collision with the Flutter widget's
/// `FriendActivityStatus` enum in `friend_activity_card.dart`.
enum FriendActivityType { inGame, inLobby, online, offline }

/// Real-time activity information about a friend.
///
/// Derived from the `profiles.current_activity` JSONB field.
class FriendActivity extends Equatable {
  final String friendId;
  final String displayName;
  final String? avatarUrl;
  final FriendActivityType status;
  final String? gameType;
  final String? roomId;
  final String? statusDetail;

  const FriendActivity({
    required this.friendId,
    required this.displayName,
    this.avatarUrl,
    required this.status,
    this.gameType,
    this.roomId,
    this.statusDetail,
  });

  /// Whether this friend can be joined in their current room.
  bool get isJoinable => status == FriendActivityType.inLobby && roomId != null;

  /// Whether this friend's game can be spectated.
  bool get isWatchable => status == FriendActivityType.inGame && roomId != null;

  @override
  List<Object?> get props => [
        friendId,
        displayName,
        status,
        gameType,
        roomId,
      ];

  factory FriendActivity.fromProfileJson(
    Map<String, dynamic> profile,
  ) {
    final activity = profile['current_activity'] as Map<String, dynamic>?;
    final FriendActivityType type;
    String? gameType;
    String? roomId;
    String? statusDetail;

    if (activity == null) {
      // Online but not in a game
      type = FriendActivityType.online;
    } else {
      final activityType = activity['type'] as String?;
      switch (activityType) {
        case 'in_game':
          type = FriendActivityType.inGame;
          gameType = activity['game_type'] as String?;
          roomId = activity['room_id'] as String?;
          statusDetail = 'Playing ${_formatGameType(gameType)}';
        case 'in_lobby':
          type = FriendActivityType.inLobby;
          gameType = activity['game_type'] as String?;
          roomId = activity['room_id'] as String?;
          statusDetail = 'In lobby';
        default:
          type = FriendActivityType.online;
      }
    }

    return FriendActivity(
      friendId: profile['id'] as String,
      displayName:
          profile['display_name'] as String? ??
          profile['username'] as String? ??
          'Unknown',
      avatarUrl: profile['avatar_url'] as String?,
      status: type,
      gameType: gameType,
      roomId: roomId,
      statusDetail: statusDetail,
    );
  }

  static String _formatGameType(String? gameType) {
    if (gameType == null) return '';
    return gameType
        .split('_')
        .map(
          (w) =>
              w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
  }
}
