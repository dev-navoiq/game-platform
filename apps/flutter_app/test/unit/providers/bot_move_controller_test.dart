import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/features/game/providers/bot_move_controller.dart';
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabase;
  late TwentyNineRules rules;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseService();
    rules = TwentyNineRules();
    // Default: accept any move so the bot's sendMove doesn't blow up.
    when(() => mockSupabase.sendMove(
          roomId: any(named: 'roomId'),
          move: any(named: 'move'),
        )).thenAnswer((_) async => <String, dynamic>{'valid': true});
  });

  ProviderContainer buildContainer({
    required TwentyNineState initialState,
    List<BotInfo> bots = const [],
  }) {
    final container = ProviderContainer(overrides: [
      supabaseServiceProvider.overrideWithValue(mockSupabase),
    ]);
    container.read(gameStateProvider.notifier).updateState(initialState);
    container.read(roomBotsProvider.notifier).state = bots;
    return container;
  }

  /// Build a bidding-phase state with [currentPlayerId] up to act.
  /// Players: host, joiner, bot-1, bot-2 (seats 0..3).
  TwentyNineState biddingState({required String currentPlayerId}) {
    return rules
        .createInitialState(
          playerIds: const ['host', 'joiner', 'bot-medium-1', 'bot-medium-2'],
          dealerIndex: 0,
        )
        .copyWith(currentPlayerId: currentPlayerId);
  }

  group('BotMoveController', () {
    test('processes the initial state on attach (regression: bot in first seat)',
        () async {
      // Bug we just fixed: `_ref.listen` only fires on FUTURE changes. If
      // the host's _startGame() seeded gameStateProvider with a state where
      // a bot is already up to bid (random dealer rotation), the controller
      // never saw it and the auction stalled. startWatching() must process
      // whatever state is already in the provider.
      final container = buildContainer(
        initialState: biddingState(currentPlayerId: 'bot-medium-1'),
        bots: const [BotInfo(id: 'bot-medium-1', difficulty: 'medium')],
      );
      addTearDown(container.dispose);

      container
          .read(botMoveControllerProvider)
          .startWatching(roomId: 'room-1');

      // Bot move is scheduled with an 800ms "thinking" delay. Wait it out.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      verify(() => mockSupabase.sendMove(
            roomId: 'room-1',
            move: any(named: 'move'),
          )).called(1);
    });

    test('ignores non-bot turns', () async {
      final container = buildContainer(
        initialState: biddingState(currentPlayerId: 'joiner'),
        bots: const [BotInfo(id: 'bot-medium-1', difficulty: 'medium')],
      );
      addTearDown(container.dispose);

      container
          .read(botMoveControllerProvider)
          .startWatching(roomId: 'room-1');

      await Future<void>.delayed(const Duration(milliseconds: 900));

      verifyNever(() => mockSupabase.sendMove(
            roomId: any(named: 'roomId'),
            move: any(named: 'move'),
          ));
    });

    test('is a no-op when the bots list is empty', () async {
      // Joiner devices never populate roomBotsProvider — only the host does.
      // The joiner's controller must stay silent on every state change so the
      // host stays the sole authority for bot moves (no double-send race).
      final container = buildContainer(
        initialState: biddingState(currentPlayerId: 'bot-medium-1'),
        bots: const [],
      );
      addTearDown(container.dispose);

      container
          .read(botMoveControllerProvider)
          .startWatching(roomId: 'room-1');

      await Future<void>.delayed(const Duration(milliseconds: 900));

      verifyNever(() => mockSupabase.sendMove(
            roomId: any(named: 'roomId'),
            move: any(named: 'move'),
          ));
    });

    test('fires when turn rotates to a bot after attach', () async {
      // Initial state has a human up — controller should sit silent. When
      // the state updates and the new currentPlayerId is a bot, the move
      // fires. This is the normal in-game path that the Riverpod listener
      // covers; we test it to lock in the rotation behaviour.
      final container = buildContainer(
        initialState: biddingState(currentPlayerId: 'host'),
        bots: const [BotInfo(id: 'bot-medium-1', difficulty: 'medium')],
      );
      addTearDown(container.dispose);

      container
          .read(botMoveControllerProvider)
          .startWatching(roomId: 'room-1');

      // Settle the initial-state pass (should not send).
      await Future<void>.delayed(const Duration(milliseconds: 900));
      verifyNever(() => mockSupabase.sendMove(
            roomId: any(named: 'roomId'),
            move: any(named: 'move'),
          ));

      // Rotate to the bot.
      container
          .read(gameStateProvider.notifier)
          .updateState(biddingState(currentPlayerId: 'bot-medium-1'));

      await Future<void>.delayed(const Duration(milliseconds: 900));

      verify(() => mockSupabase.sendMove(
            roomId: 'room-1',
            move: any(named: 'move'),
          )).called(1);
    });

    test('dispose cancels a pending move', () async {
      // If the game screen tears down while a bot's 800ms timer is in
      // flight, the controller must not send the move from the destroyed
      // session — otherwise we get phantom moves after the user leaves.
      final container = buildContainer(
        initialState: biddingState(currentPlayerId: 'bot-medium-1'),
        bots: const [BotInfo(id: 'bot-medium-1', difficulty: 'medium')],
      );

      final controller = container.read(botMoveControllerProvider);
      controller.startWatching(roomId: 'room-1');

      // Dispose before the 800ms timer fires.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      container.dispose();

      // Wait past the original delay.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      verifyNever(() => mockSupabase.sendMove(
            roomId: any(named: 'roomId'),
            move: any(named: 'move'),
          ));
    });
  });
}
