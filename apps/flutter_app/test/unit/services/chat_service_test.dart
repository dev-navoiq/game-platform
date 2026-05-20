import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/core/services/chat_service.dart';
import 'package:flutter_app/core/services/supabase_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabase;
  late ChatService chatService;

  setUp(() {
    mockSupabase = MockSupabaseService();
    chatService = ChatService(supabase: mockSupabase);
  });

  group('ChatService', () {
    test('sendMessage calls supabase with correct parameters', () async {
      when(() => mockSupabase.insertChatMessage(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
            senderId: any(named: 'senderId'),
          )).thenAnswer((_) async {});

      await chatService.sendMessage(
        roomId: 'room-abc',
        message: 'Hello!',
        senderId: 'user-1',
      );

      verify(() => mockSupabase.insertChatMessage(
            roomId: 'room-abc',
            message: 'Hello!',
            senderId: 'user-1',
          )).called(1);
    });

    test('sendMessage trims whitespace from message', () async {
      when(() => mockSupabase.insertChatMessage(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
            senderId: any(named: 'senderId'),
          )).thenAnswer((_) async {});

      await chatService.sendMessage(
        roomId: 'room-abc',
        message: '  Hello!  ',
        senderId: 'user-1',
      );

      verify(() => mockSupabase.insertChatMessage(
            roomId: 'room-abc',
            message: 'Hello!',
            senderId: 'user-1',
          )).called(1);
    });

    test('sendMessage rejects empty message', () async {
      await expectLater(
        () => chatService.sendMessage(
          roomId: 'room-abc',
          message: '   ',
          senderId: 'user-1',
        ),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => mockSupabase.insertChatMessage(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
            senderId: any(named: 'senderId'),
          ));
    });

    test('sendMessage enforces max length', () async {
      final longMessage = 'a' * 501; // > 500 char limit

      await expectLater(
        () => chatService.sendMessage(
          roomId: 'room-abc',
          message: longMessage,
          senderId: 'user-1',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('subscribeToMessages sets up realtime channel', () {
      when(() => mockSupabase.subscribeToRoomMessages(
            roomId: any(named: 'roomId'),
            onMessage: any(named: 'onMessage'),
          )).thenReturn(null);

      chatService.subscribeToMessages(
        roomId: 'room-abc',
        onMessage: (_) {},
      );

      verify(() => mockSupabase.subscribeToRoomMessages(
            roomId: 'room-abc',
            onMessage: any(named: 'onMessage'),
          )).called(1);
    });
  });
}
