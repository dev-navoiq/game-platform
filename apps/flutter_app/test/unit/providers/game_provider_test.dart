import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabase;

  setUp(() {
    mockSupabase = MockSupabaseService();
  });

  final rules = TwentyNineRules();

  TwentyNineState biddingState({String currentPlayerId = 'p1'}) => rules
      .createInitialState(
        playerIds: const ['p1', 'p2', 'p3', 'p4'],
        dealerIndex: 0,
      )
      .copyWith(currentPlayerId: currentPlayerId);

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
            onHealth: any(named: 'onHealth'),
          )).thenReturn(GameStateSubscription.inert());

      final container = buildContainer();
      addTearDown(container.dispose);

      final notifier = container.read(gameStateProvider.notifier);
      await notifier.subscribeToGame(roomId: 'room-123');

      verify(() => mockSupabase.subscribeToGameState(
            roomId: 'room-123',
            onUpdate: any(named: 'onUpdate'),
            onHealth: any(named: 'onHealth'),
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

  group('GameProvider optimistic moves', () {
    test('applies a deterministic move locally before the server confirms, '
        'then reconciles to the server result', () async {
      final initial = biddingState();
      final serverState = rules
          .applyMove(initial, const BidMove(playerId: 'p1', bidValue: 16))
          .newState;

      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.setGameType('twenty_nine');
      notifier.updateState(initial);

      TwentyNineState? midFlight;
      when(() => mockSupabase.sendMove(
            roomId: any(named: 'roomId'),
            move: any(named: 'move'),
          )).thenAnswer((_) async {
        // By the time the request is in flight the UI has already advanced —
        // that's the optimistic update.
        midFlight = container.read(gameStateProvider) as TwentyNineState;
        return {'new_state': serverState.toJson()};
      });

      await notifier.sendMoveOptimistic(
        roomId: 'room-1',
        localMove: const BidMove(playerId: 'p1', bidValue: 16),
        wireMove: const {'type': 'bid', 'player_id': 'p1', 'bid_value': 16},
      );

      expect(midFlight?.currentBid, 16, reason: 'applied before server replied');
      final finalState = container.read(gameStateProvider) as TwentyNineState;
      expect(finalState.currentBid, 16);
      expect(finalState.bidderId, 'p1');
    });

    test('rolls back the optimistic state when the server rejects the move',
        () async {
      final initial = biddingState();

      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.setGameType('twenty_nine');
      notifier.updateState(initial);

      when(() => mockSupabase.sendMove(
            roomId: any(named: 'roomId'),
            move: any(named: 'move'),
          )).thenAnswer((_) async =>
          throw const MoveRejection(code: 'BID_TOO_LOW', message: 'too low'));

      await expectLater(
        notifier.sendMoveOptimistic(
          roomId: 'room-1',
          localMove: const BidMove(playerId: 'p1', bidValue: 16),
          wireMove: const {'type': 'bid', 'player_id': 'p1', 'bid_value': 16},
        ),
        throwsA(isA<MoveRejection>()),
      );

      final finalState = container.read(gameStateProvider) as TwentyNineState;
      expect(finalState, initial, reason: 'rolled back to the pre-move state');
    });

    test('realtime backstop ignores states older than the current turn',
        () async {
      Function? onUpdate;
      when(() => mockSupabase.subscribeToGameState(
            roomId: any(named: 'roomId'),
            onUpdate: any(named: 'onUpdate'),
            onHealth: any(named: 'onHealth'),
          )).thenAnswer((inv) {
        onUpdate = inv.namedArguments[#onUpdate] as Function;
        return GameStateSubscription.inert();
      });

      final container = buildContainer();
      addTearDown(container.dispose);
      final notifier = container.read(gameStateProvider.notifier);
      notifier.setGameType('twenty_nine');

      final base = biddingState();
      notifier.updateState(base.copyWith(turnNumber: 5, currentBid: 20));
      await notifier.subscribeToGame(roomId: 'room-1');

      // Stale echo (older turn) — must be dropped.
      onUpdate!({
        'state_data': base.copyWith(turnNumber: 3, currentBid: 17).toJson(),
      });
      expect((container.read(gameStateProvider) as TwentyNineState).currentBid,
          20);

      // Newer state — must be applied.
      onUpdate!({
        'state_data': base.copyWith(turnNumber: 6, currentBid: 25).toJson(),
      });
      expect((container.read(gameStateProvider) as TwentyNineState).currentBid,
          25);
    });
  });
}
