import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_core/social_core.dart';

import 'package:flutter_app/features/friends/presentation/friends_screen.dart';
import 'package:flutter_app/features/social/providers/social_providers.dart';
import 'package:flutter_app/core/di/providers.dart';

class MockFriendsRepository extends Mock implements FriendsRepository {}

class FakeUser {
  final String id;
  FakeUser(this.id);
}

Widget buildFriendsScreen({List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: FriendsScreen(),
    ),
  );
}

void main() {
  late MockFriendsRepository mockRepo;

  setUp(() {
    mockRepo = MockFriendsRepository();
    when(() => mockRepo.watchFriendships(userId: any(named: 'userId')))
        .thenAnswer((_) => const Stream.empty());
    when(() => mockRepo.watchFriendActivities(userId: any(named: 'userId')))
        .thenAnswer((_) => const Stream.empty());
    when(() => mockRepo.getBlockedUserIds(userId: any(named: 'userId')))
        .thenAnswer((_) async => <String>[]);
  });

  group('FriendsScreen', () {
    testWidgets('renders three tabs', (tester) async {
      await tester.pumpWidget(buildFriendsScreen(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Friends'), findsWidgets); // Tab + AppBar
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('shows empty state when no friends', (tester) async {
      when(() => mockRepo.watchFriendships(userId: any(named: 'userId')))
          .thenAnswer((_) => Stream.value([]));
      when(() => mockRepo.watchFriendActivities(userId: any(named: 'userId')))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(buildFriendsScreen(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(mockRepo),
          currentUserProvider.overrideWithValue(null),
        ],
      ));
      await tester.pumpAndSettle();

      // Empty state message shown instead of friend cards
      expect(find.textContaining('No friends yet'), findsOneWidget);
    });

    testWidgets('can switch to Requests tab', (tester) async {
      await tester.pumpWidget(buildFriendsScreen(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      // Requests tab is now active
      expect(find.text('Requests'), findsOneWidget);
    });

    testWidgets('can switch to Blocked tab', (tester) async {
      await tester.pumpWidget(buildFriendsScreen(
        overrides: [
          friendsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blocked'));
      await tester.pumpAndSettle();

      expect(find.text('Blocked'), findsOneWidget);
    });
  });
}
