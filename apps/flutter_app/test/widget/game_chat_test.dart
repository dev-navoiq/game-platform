import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_core/social_core.dart';

import 'package:flutter_app/features/game/presentation/widgets/game_chat.dart';
import 'package:flutter_app/features/social/providers/social_providers.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class FakeUser {
  final String id;
  FakeUser(this.id);
}

Widget buildChat({
  required RoomSocialMode socialMode,
  required String roomId,
  bool isSpectator = false,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 400,
          child: GameChat(
            socialMode: socialMode,
            roomId: roomId,
            isSpectator: isSpectator,
          ),
        ),
      ),
    ),
  );
}

void main() {
  late MockChatRepository mockRepo;

  setUp(() {
    mockRepo = MockChatRepository();
    when(() => mockRepo.watchMessages(
          roomId: any(named: 'roomId'),
          isSpectatorChat: any(named: 'isSpectatorChat'),
        )).thenAnswer((_) => const Stream.empty());
  });

  group('GameChat visibility', () {
    testWidgets('hidden in silent mode', (tester) async {
      await tester.pumpWidget(buildChat(
        socialMode: RoomSocialMode.silent,
        roomId: 'room-1',
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      expect(find.text('Chat'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('hidden in focus mode', (tester) async {
      await tester.pumpWidget(buildChat(
        socialMode: RoomSocialMode.focus,
        roomId: 'room-1',
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      expect(find.text('Chat'), findsNothing);
    });

    testWidgets('visible in full mode', (tester) async {
      await tester.pumpWidget(buildChat(
        socialMode: RoomSocialMode.full,
        roomId: 'room-1',
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('visible in chatOnly mode', (tester) async {
      await tester.pumpWidget(buildChat(
        socialMode: RoomSocialMode.chatOnly,
        roomId: 'room-1',
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('shows Spectator Chat header for spectators', (tester) async {
      await tester.pumpWidget(buildChat(
        socialMode: RoomSocialMode.full,
        roomId: 'room-1',
        isSpectator: true,
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Spectator Chat'), findsOneWidget);
    });
  });

  group('GameChat messages', () {
    testWidgets('renders messages from provider stream', (tester) async {
      final controller = StreamController<List<ChatMessage>>.broadcast();
      when(() => mockRepo.watchMessages(
            roomId: 'room-1',
            isSpectatorChat: false,
          )).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(buildChat(
        socialMode: RoomSocialMode.full,
        roomId: 'room-1',
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockRepo),
        ],
      ));
      await tester.pumpAndSettle();

      controller.add([
        ChatMessage(
          id: 'm1',
          roomId: 'room-1',
          userId: 'u1',
          senderName: 'Alice',
          content: 'Hello everyone!',
          createdAt: DateTime.now(),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Hello everyone!'), findsOneWidget);

      controller.close();
    });
  });
}
