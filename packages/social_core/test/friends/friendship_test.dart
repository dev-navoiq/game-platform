import 'package:test/test.dart';
import 'package:social_core/social_core.dart';

void main() {
  group('Friendship', () {
    final now = DateTime(2026, 3, 1);

    test('two friendships with same fields are equal', () {
      final a = Friendship(
        id: '1',
        userId: 'user-a',
        friendId: 'user-b',
        status: FriendshipStatus.accepted,
        createdAt: now,
      );
      final b = Friendship(
        id: '1',
        userId: 'user-a',
        friendId: 'user-b',
        status: FriendshipStatus.accepted,
        createdAt: now,
      );
      expect(a, equals(b));
    });

    test('different IDs produce inequality', () {
      final a = Friendship(
        id: '1',
        userId: 'user-a',
        friendId: 'user-b',
        status: FriendshipStatus.accepted,
        createdAt: now,
      );
      final b = Friendship(
        id: '2',
        userId: 'user-a',
        friendId: 'user-b',
        status: FriendshipStatus.accepted,
        createdAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('different status produces inequality', () {
      final a = Friendship(
        id: '1',
        userId: 'user-a',
        friendId: 'user-b',
        status: FriendshipStatus.pending,
        createdAt: now,
      );
      final b = Friendship(
        id: '1',
        userId: 'user-a',
        friendId: 'user-b',
        status: FriendshipStatus.accepted,
        createdAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('fromJson creates valid friendship', () {
      final json = {
        'id': 'abc',
        'user_id': 'u1',
        'friend_id': 'u2',
        'status': 'pending',
        'created_at': '2026-03-01T00:00:00.000Z',
      };
      final f = Friendship.fromJson(json);
      expect(f.id, 'abc');
      expect(f.userId, 'u1');
      expect(f.friendId, 'u2');
      expect(f.status, FriendshipStatus.pending);
    });
  });

  group('FriendshipStatus', () {
    test('has all 4 values', () {
      expect(FriendshipStatus.values, hasLength(4));
      expect(FriendshipStatus.values, contains(FriendshipStatus.pending));
      expect(FriendshipStatus.values, contains(FriendshipStatus.accepted));
      expect(FriendshipStatus.values, contains(FriendshipStatus.declined));
      expect(FriendshipStatus.values, contains(FriendshipStatus.blocked));
    });
  });

  group('FriendActivity', () {
    test('two activities with same fields are equal', () {
      final a = FriendActivity(
        friendId: 'u1',
        displayName: 'Alice',
        status: FriendActivityType.inGame,
        gameType: 'chess',
        roomId: 'room-1',
      );
      final b = FriendActivity(
        friendId: 'u1',
        displayName: 'Alice',
        status: FriendActivityType.inGame,
        gameType: 'chess',
        roomId: 'room-1',
      );
      expect(a, equals(b));
    });

    test('isJoinable returns true for inLobby with roomId', () {
      final activity = FriendActivity(
        friendId: 'u1',
        displayName: 'Alice',
        status: FriendActivityType.inLobby,
        roomId: 'room-1',
      );
      expect(activity.isJoinable, isTrue);
    });

    test('isJoinable returns false for inGame', () {
      final activity = FriendActivity(
        friendId: 'u1',
        displayName: 'Alice',
        status: FriendActivityType.inGame,
        roomId: 'room-1',
      );
      expect(activity.isJoinable, isFalse);
    });

    test('isWatchable returns true for inGame with roomId', () {
      final activity = FriendActivity(
        friendId: 'u1',
        displayName: 'Alice',
        status: FriendActivityType.inGame,
        roomId: 'room-1',
      );
      expect(activity.isWatchable, isTrue);
    });

    test('isWatchable returns false without roomId', () {
      final activity = FriendActivity(
        friendId: 'u1',
        displayName: 'Alice',
        status: FriendActivityType.inGame,
      );
      expect(activity.isWatchable, isFalse);
    });

    test('fromProfileJson handles null current_activity as online', () {
      final profile = {
        'id': 'u1',
        'display_name': 'Alice',
        'avatar_url': null,
        'current_activity': null,
      };
      final activity = FriendActivity.fromProfileJson(profile);
      expect(activity.status, FriendActivityType.online);
    });

    test('fromProfileJson handles in_game activity', () {
      final profile = {
        'id': 'u1',
        'display_name': 'Alice',
        'current_activity': {
          'type': 'in_game',
          'game_type': 'oh_hell',
          'room_id': 'room-1',
        },
      };
      final activity = FriendActivity.fromProfileJson(profile);
      expect(activity.status, FriendActivityType.inGame);
      expect(activity.gameType, 'oh_hell');
      expect(activity.roomId, 'room-1');
    });

    test('fromProfileJson handles in_lobby activity', () {
      final profile = {
        'id': 'u1',
        'display_name': 'Alice',
        'current_activity': {
          'type': 'in_lobby',
          'game_type': 'chess',
          'room_id': 'room-2',
        },
      };
      final activity = FriendActivity.fromProfileJson(profile);
      expect(activity.status, FriendActivityType.inLobby);
      expect(activity.gameType, 'chess');
    });
  });

  group('FriendActivityType', () {
    test('has all 4 values', () {
      expect(FriendActivityType.values, hasLength(4));
      expect(FriendActivityType.values, contains(FriendActivityType.inGame));
      expect(FriendActivityType.values, contains(FriendActivityType.inLobby));
      expect(FriendActivityType.values, contains(FriendActivityType.online));
      expect(FriendActivityType.values, contains(FriendActivityType.offline));
    });
  });
}
