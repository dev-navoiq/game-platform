import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:game_core/game_core.dart';

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

  group('GameProvider', () {
    test('initial state is null (no active game)', () {
      final container = buildContainer();
      addTearDown(container.dispose);

      final state = container.read(gameStateProvider);
      expect(state, isNull);
    });

    test('subscribeToGame sets up realtime listener', () async {
      when(() => mockSupabase.subscribeToGameState(
            roomId: any(named: 'roomId'),
            onUpdate: any(named: 'onUpdate'),
          )).thenReturn(null);

      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.subscribeToGame(roomId: 'room-123');

      verify(() => mockSupabase.subscribeToGameState(
            roomId: 'room-123',
            onUpdate: any(named: 'onUpdate'),
          )).called(1);
    });

    test('sendMove dispatches to supabase', () async {
      when(() => mockSupabase.sendMove(
            roomId: any(named: 'roomId'),
            move: any(named: 'move'),
          )).thenAnswer((_) async => <String, dynamic>{'valid': true});

      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.sendMove(
        roomId: 'room-123',
        move: const BidMoveDto(playerId: 'p1', bidValue: 16),
      );

      verify(() => mockSupabase.sendMove(
            roomId: 'room-123',
            move: any(named: 'move'),
          )).called(1);
    });
  });
}
