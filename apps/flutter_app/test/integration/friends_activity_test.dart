import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_core/social_core.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

void main() {
  late MockFriendsRepository mockRepo;

  const userId = 'user-1';
  const friendId = 'friend-1';
  const friendshipId = 'friendship-1';

  final now = DateTime(2026, 3, 8);

  final onlineFriend = const FriendActivity(
    friendId: friendId,
    displayName: 'Alice',
    avatarUrl: 'https://example.com/alice.png',
    status: FriendActivityType.online,
  );

  final inGameFriend = const FriendActivity(
    friendId: friendId,
    displayName: 'Alice',
    status: FriendActivityType.inGame,
    gameType: 'chess',
    roomId: 'room-42',
    statusDetail: 'Playing Chess',
  );

  final inLobbyFriend = const FriendActivity(
    friendId: friendId,
    displayName: 'Alice',
    status: FriendActivityType.inLobby,
    gameType: 'twenty_nine',
    roomId: 'room-99',
    statusDetail: 'In lobby',
  );

  final offlineFriend = const FriendActivity(
    friendId: friendId,
    displayName: 'Alice',
    status: FriendActivityType.offline,
  );

  final inGameNoRoom = const FriendActivity(
    friendId: friendId,
    displayName: 'Alice',
    status: FriendActivityType.inGame,
    gameType: 'chess',
  );

  final inLobbyNoRoom = const FriendActivity(
    friendId: friendId,
    displayName: 'Alice',
    status: FriendActivityType.inLobby,
    gameType: 'twenty_nine',
  );

  final pendingFriendship = Friendship(
    id: friendshipId,
    userId: userId,
    friendId: friendId,
    friendName: 'Alice',
    status: FriendshipStatus.pending,
    createdAt: now,
  );

  final acceptedFriendship = Friendship(
    id: friendshipId,
    userId: userId,
    friendId: friendId,
    friendName: 'Alice',
    status: FriendshipStatus.accepted,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    mockRepo = MockFriendsRepository();
  });

  group('Friend activity status', () {
    test('shows correct status for online friend', () async {
      when(() => mockRepo.getFriendActivities(userId: userId))
          .thenAnswer((_) async => [onlineFriend]);

      final activities = await mockRepo.getFriendActivities(userId: userId);

      expect(activities, hasLength(1));
      expect(activities.first.status, FriendActivityType.online);
      expect(activities.first.displayName, 'Alice');
    });

    test('shows correct status for friend in game', () async {
      when(() => mockRepo.getFriendActivities(userId: userId))
          .thenAnswer((_) async => [inGameFriend]);

      final activities = await mockRepo.getFriendActivities(userId: userId);

      expect(activities.first.status, FriendActivityType.inGame);
      expect(activities.first.gameType, 'chess');
      expect(activities.first.roomId, 'room-42');
      expect(activities.first.statusDetail, 'Playing Chess');
    });

    test('shows correct status for friend in lobby', () async {
      when(() => mockRepo.getFriendActivities(userId: userId))
          .thenAnswer((_) async => [inLobbyFriend]);

      final activities = await mockRepo.getFriendActivities(userId: userId);

      expect(activities.first.status, FriendActivityType.inLobby);
      expect(activities.first.gameType, 'twenty_nine');
      expect(activities.first.roomId, 'room-99');
    });

    test('shows correct status for offline friend', () async {
      when(() => mockRepo.getFriendActivities(userId: userId))
          .thenAnswer((_) async => [offlineFriend]);

      final activities = await mockRepo.getFriendActivities(userId: userId);

      expect(activities.first.status, FriendActivityType.offline);
      expect(activities.first.roomId, isNull);
    });
  });

  group('isJoinable', () {
    test('is true only for inLobby with roomId', () {
      expect(inLobbyFriend.isJoinable, isTrue);
    });

    test('is false for inLobby without roomId', () {
      expect(inLobbyNoRoom.isJoinable, isFalse);
    });

    test('is false for inGame even with roomId', () {
      expect(inGameFriend.isJoinable, isFalse);
    });

    test('is false for online', () {
      expect(onlineFriend.isJoinable, isFalse);
    });

    test('is false for offline', () {
      expect(offlineFriend.isJoinable, isFalse);
    });
  });

  group('isWatchable', () {
    test('is true only for inGame with roomId', () {
      expect(inGameFriend.isWatchable, isTrue);
    });

    test('is false for inGame without roomId', () {
      expect(inGameNoRoom.isWatchable, isFalse);
    });

    test('is false for inLobby even with roomId', () {
      expect(inLobbyFriend.isWatchable, isFalse);
    });

    test('is false for online', () {
      expect(onlineFriend.isWatchable, isFalse);
    });

    test('is false for offline', () {
      expect(offlineFriend.isWatchable, isFalse);
    });
  });

  group('Friend request flow', () {
    test('send request → accept → appears in accepted list', () async {
      // Arrange: send request returns void
      when(() => mockRepo.sendFriendRequest(
            userId: userId,
            friendId: friendId,
          )).thenAnswer((_) async {});

      // After sending, pending friendship appears
      when(() => mockRepo.getFriendships(
            userId: userId,
            status: FriendshipStatus.pending,
          )).thenAnswer((_) async => [pendingFriendship]);

      // Accept the request
      when(() => mockRepo.acceptFriendRequest(friendshipId: friendshipId))
          .thenAnswer((_) async {});

      // After accepting, accepted friendship appears
      when(() => mockRepo.getFriendships(
            userId: userId,
            status: FriendshipStatus.accepted,
          )).thenAnswer((_) async => [acceptedFriendship]);

      // Act: send request
      await mockRepo.sendFriendRequest(userId: userId, friendId: friendId);

      // Verify pending
      final pending = await mockRepo.getFriendships(
        userId: userId,
        status: FriendshipStatus.pending,
      );
      expect(pending, hasLength(1));
      expect(pending.first.status, FriendshipStatus.pending);

      // Act: accept
      await mockRepo.acceptFriendRequest(friendshipId: friendshipId);

      // Verify accepted
      final accepted = await mockRepo.getFriendships(
        userId: userId,
        status: FriendshipStatus.accepted,
      );
      expect(accepted, hasLength(1));
      expect(accepted.first.status, FriendshipStatus.accepted);
      expect(accepted.first.friendName, 'Alice');

      // Verify call order
      verifyInOrder([
        () => mockRepo.sendFriendRequest(userId: userId, friendId: friendId),
        () => mockRepo.getFriendships(
              userId: userId,
              status: FriendshipStatus.pending,
            ),
        () => mockRepo.acceptFriendRequest(friendshipId: friendshipId),
        () => mockRepo.getFriendships(
              userId: userId,
              status: FriendshipStatus.accepted,
            ),
      ]);
    });
  });

  group('Stream-based activity updates', () {
    test('friend goes online and status changes are streamed', () async {
      final controller = StreamController<List<FriendActivity>>();

      when(() => mockRepo.watchFriendActivities(userId: userId))
          .thenAnswer((_) => controller.stream);

      final stream = mockRepo.watchFriendActivities(userId: userId);
      final emissions = <List<FriendActivity>>[];
      final subscription = stream.listen(emissions.add);

      // Friend comes online
      controller.add([onlineFriend]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(1));
      expect(emissions.last.first.status, FriendActivityType.online);

      // Friend enters a lobby
      controller.add([inLobbyFriend]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(2));
      expect(emissions.last.first.status, FriendActivityType.inLobby);
      expect(emissions.last.first.isJoinable, isTrue);

      // Friend starts a game
      controller.add([inGameFriend]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(3));
      expect(emissions.last.first.status, FriendActivityType.inGame);
      expect(emissions.last.first.isWatchable, isTrue);
      expect(emissions.last.first.isJoinable, isFalse);

      // Friend goes offline
      controller.add([offlineFriend]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(4));
      expect(emissions.last.first.status, FriendActivityType.offline);

      await subscription.cancel();
      await controller.close();
    });
  });

  group('Blocked user filtering', () {
    test('blocked user is not shown in activity list', () async {
      const blockedFriendId = 'blocked-user-1';

      final blockedActivity = const FriendActivity(
        friendId: blockedFriendId,
        displayName: 'BlockedBob',
        status: FriendActivityType.online,
      );

      // Block the user
      when(() => mockRepo.blockUser(
            blockerId: userId,
            blockedId: blockedFriendId,
          )).thenAnswer((_) async {});

      when(() => mockRepo.getBlockedUserIds(userId: userId))
          .thenAnswer((_) async => [blockedFriendId]);

      // Activity list returns both friends
      when(() => mockRepo.getFriendActivities(userId: userId))
          .thenAnswer((_) async => [onlineFriend, blockedActivity]);

      // Act: block the user
      await mockRepo.blockUser(blockerId: userId, blockedId: blockedFriendId);

      // Get blocked IDs
      final blockedIds = await mockRepo.getBlockedUserIds(userId: userId);
      expect(blockedIds, contains(blockedFriendId));

      // Filter activities client-side (simulating app logic)
      final activities = await mockRepo.getFriendActivities(userId: userId);
      final filtered = activities
          .where((a) => !blockedIds.contains(a.friendId))
          .toList();

      expect(filtered, hasLength(1));
      expect(filtered.first.friendId, friendId);
      expect(filtered.first.displayName, 'Alice');
    });
  });

  group('FriendActivity.fromProfileJson', () {
    test('parses online profile without current_activity', () {
      final json = {
        'id': 'user-42',
        'display_name': 'Charlie',
        'avatar_url': 'https://example.com/charlie.png',
      };

      final activity = FriendActivity.fromProfileJson(json);

      expect(activity.friendId, 'user-42');
      expect(activity.displayName, 'Charlie');
      expect(activity.avatarUrl, 'https://example.com/charlie.png');
      expect(activity.status, FriendActivityType.online);
      expect(activity.roomId, isNull);
    });

    test('parses in_game activity from profile JSON', () {
      final json = {
        'id': 'user-42',
        'display_name': 'Charlie',
        'current_activity': {
          'type': 'in_game',
          'game_type': 'chess',
          'room_id': 'room-7',
        },
      };

      final activity = FriendActivity.fromProfileJson(json);

      expect(activity.status, FriendActivityType.inGame);
      expect(activity.gameType, 'chess');
      expect(activity.roomId, 'room-7');
      expect(activity.statusDetail, 'Playing Chess');
      expect(activity.isWatchable, isTrue);
    });

    test('parses in_lobby activity from profile JSON', () {
      final json = {
        'id': 'user-42',
        'username': 'charlie99',
        'current_activity': {
          'type': 'in_lobby',
          'game_type': 'twenty_nine',
          'room_id': 'room-55',
        },
      };

      final activity = FriendActivity.fromProfileJson(json);

      expect(activity.displayName, 'charlie99');
      expect(activity.status, FriendActivityType.inLobby);
      expect(activity.roomId, 'room-55');
      expect(activity.statusDetail, 'In lobby');
      expect(activity.isJoinable, isTrue);
    });

    test('falls back to Unknown when no name fields present', () {
      final json = {
        'id': 'user-42',
      };

      final activity = FriendActivity.fromProfileJson(json);

      expect(activity.displayName, 'Unknown');
      expect(activity.status, FriendActivityType.online);
    });
  });

  group('Full integration: friend request → activity → quick join', () {
    test(
        'send request → accept → friend goes online → see status → '
        'quick join available when in lobby', () async {
      final activityController = StreamController<List<FriendActivity>>();

      // Step 1: Send friend request
      when(() => mockRepo.sendFriendRequest(
            userId: userId,
            friendId: friendId,
          )).thenAnswer((_) async {});

      // Step 2: Accept friend request
      when(() => mockRepo.acceptFriendRequest(friendshipId: friendshipId))
          .thenAnswer((_) async {});

      when(() => mockRepo.getFriendships(
            userId: userId,
            status: FriendshipStatus.accepted,
          )).thenAnswer((_) async => [acceptedFriendship]);

      // Step 3: Watch friend activities
      when(() => mockRepo.watchFriendActivities(userId: userId))
          .thenAnswer((_) => activityController.stream);

      // No blocked users
      when(() => mockRepo.getBlockedUserIds(userId: userId))
          .thenAnswer((_) async => []);

      // --- Execute the flow ---

      // Send and accept the friend request
      await mockRepo.sendFriendRequest(userId: userId, friendId: friendId);
      await mockRepo.acceptFriendRequest(friendshipId: friendshipId);

      // Verify friendship is accepted
      final friendships = await mockRepo.getFriendships(
        userId: userId,
        status: FriendshipStatus.accepted,
      );
      expect(friendships, hasLength(1));
      expect(friendships.first.status, FriendshipStatus.accepted);

      // Start watching activities
      final blockedIds = await mockRepo.getBlockedUserIds(userId: userId);
      final stream = mockRepo.watchFriendActivities(userId: userId);
      final emissions = <List<FriendActivity>>[];
      final subscription = stream.listen((activities) {
        // Filter blocked users (app-level logic)
        final visible = activities
            .where((a) => !blockedIds.contains(a.friendId))
            .toList();
        emissions.add(visible);
      });

      // Friend comes online
      activityController.add([onlineFriend]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(1));
      expect(emissions.last.first.status, FriendActivityType.online);
      expect(emissions.last.first.isJoinable, isFalse);
      expect(emissions.last.first.isWatchable, isFalse);

      // Friend enters lobby — quick join should be available
      activityController.add([inLobbyFriend]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(2));
      final lobbyActivity = emissions.last.first;
      expect(lobbyActivity.status, FriendActivityType.inLobby);
      expect(lobbyActivity.isJoinable, isTrue);
      expect(lobbyActivity.roomId, 'room-99');
      expect(lobbyActivity.gameType, 'twenty_nine');

      // Friend starts game — joinable becomes false, watchable becomes true
      activityController.add([inGameFriend]);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(3));
      final gameActivity = emissions.last.first;
      expect(gameActivity.status, FriendActivityType.inGame);
      expect(gameActivity.isJoinable, isFalse);
      expect(gameActivity.isWatchable, isTrue);
      expect(gameActivity.roomId, 'room-42');

      // Verify all repository calls were made
      verify(() =>
              mockRepo.sendFriendRequest(userId: userId, friendId: friendId))
          .called(1);
      verify(() =>
              mockRepo.acceptFriendRequest(friendshipId: friendshipId))
          .called(1);
      verify(() => mockRepo.watchFriendActivities(userId: userId)).called(1);

      await subscription.cancel();
      await activityController.close();
    });
  });
}
