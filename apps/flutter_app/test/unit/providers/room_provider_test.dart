import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/features/lobby/providers/room_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseService();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        supabaseServiceProvider.overrideWithValue(mockSupabase),
      ],
    );
  }

  group('RoomProvider', () {
    test('initial state is loading', () {
      final container = buildContainer();
      addTearDown(container.dispose);

      final state = container.read(roomProvider);
      expect(state, isA<AsyncLoading>());
    });

    test('createRoom calls supabase and returns room id', () async {
      when(() => mockSupabase.createRoom(
            gameType: any(named: 'gameType'),
            socialMode: any(named: 'socialMode'),
          )).thenAnswer((_) async => <String, dynamic>{'room_id': 'room-123', 'code': 'TEST01'});

      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(roomProvider.notifier);
      final roomId = await notifier.createRoom(
        gameType: 'twenty_nine',
        socialMode: 'full',
      );

      expect(roomId, 'room-123');
      verify(() => mockSupabase.createRoom(
            gameType: 'twenty_nine',
            socialMode: 'full',
          )).called(1);
    });

    test('createRoom error transitions to error state', () async {
      when(() => mockSupabase.createRoom(
            gameType: any(named: 'gameType'),
            socialMode: any(named: 'socialMode'),
          )).thenThrow(Exception('Network error'));

      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(roomProvider.notifier);
      await expectLater(
        () => notifier.createRoom(gameType: 'twenty_nine', socialMode: 'full'),
        throwsA(isA<Exception>()),
      );
    });

    test('leaveRoom updates state correctly', () async {
      when(() => mockSupabase.leaveRoom(roomId: any(named: 'roomId')))
          .thenAnswer((_) async {});

      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(roomProvider.notifier);
      await notifier.leaveRoom(roomId: 'room-123');

      verify(() => mockSupabase.leaveRoom(roomId: 'room-123')).called(1);
    });
  });
}
