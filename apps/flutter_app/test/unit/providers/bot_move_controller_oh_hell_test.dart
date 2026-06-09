// Regression tests for Bug B — BotMoveController must now drive Oh Hell bots,
// not just Twenty-Nine. Verifies that the controller emits payloads in the
// snake_case shape the edge function expects: bid_value / card / player_id.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/features/game/providers/bot_move_controller.dart';
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:game_core/game_core.dart';
import 'package:game_oh_hell/game_oh_hell.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockSupabase;

  const botId = 'bot-medium-1';
  const playerOrder = ['host', 'joiner-1', 'joiner-2', botId];

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockSupabase = MockSupabaseService();
    when(() => mockSupabase.sendMove(
          roomId: any(named: 'roomId'),
          move: any(named: 'move'),
        )).thenAnswer((_) async => <String, dynamic>{'valid': true});
  });

  ProviderContainer buildContainer({
    required OhHellState initialState,
    List<BotInfo> bots = const [],
  }) {
    final container = ProviderContainer(overrides: [
      supabaseServiceProvider.overrideWithValue(mockSupabase),
    ]);
    container.read(gameStateProvider.notifier).updateState(initialState);
    container.read(roomBotsProvider.notifier).state = bots;
    return container;
  }

  /// Bidding-phase state with [currentPlayerId] up to bid.
  /// Hands are dealt cardsThisRound=3 cards so the bot has options.
  OhHellState biddingState({required String currentPlayerId}) {
    final hands = <String, Hand>{
      for (final id in playerOrder)
        id: Hand(const [
          PlayingCard(Suit.hearts, Rank.king),
          PlayingCard(Suit.clubs, Rank.five),
          PlayingCard(Suit.diamonds, Rank.three),
        ]),
    };
    return OhHellState(
      phase: GamePhase.bidding,
      currentPlayerId: currentPlayerId,
      playerOrder: playerOrder,
      dealerIndex: 0,
      hands: hands,
      cardsThisRound: 3,
      roundSequenceIndex: 0,
      totalRounds: 25,
      bids: const {},
      tricksWon: {for (final id in playerOrder) id: 0},
      scores: {for (final id in playerOrder) id: 0},
    );
  }

  /// Playing-phase state with bot up to lead; bot has a single known card.
  OhHellState playingState({required String currentPlayerId}) {
    final hands = <String, Hand>{
      'host': Hand(const [PlayingCard(Suit.clubs, Rank.king)]),
      'joiner-1': Hand(const [PlayingCard(Suit.diamonds, Rank.queen)]),
      'joiner-2': Hand(const [PlayingCard(Suit.spades, Rank.jack)]),
      botId: Hand(const [PlayingCard(Suit.hearts, Rank.ace)]),
    };
    return OhHellState(
      phase: GamePhase.playing,
      currentPlayerId: currentPlayerId,
      playerOrder: playerOrder,
      dealerIndex: 0,
      hands: hands,
      cardsThisRound: 1,
      roundSequenceIndex: 0,
      totalRounds: 25,
      bids: const {'host': 0, 'joiner-1': 0, 'joiner-2': 0, botId: 1},
      tricksWon: {for (final id in playerOrder) id: 0},
      scores: {for (final id in playerOrder) id: 0},
    );
  }

  group('BotMoveController — Oh Hell', () {
    test('bot in bidding phase emits {type: "bid", player_id, bid_value}',
        () async {
      final container = buildContainer(
        initialState: biddingState(currentPlayerId: botId),
        bots: const [BotInfo(id: botId, difficulty: 'medium')],
      );
      addTearDown(container.dispose);

      container
          .read(botMoveControllerProvider)
          .startWatching(roomId: 'room-1');

      // Bot move is scheduled with an 800ms "thinking" delay.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final captured = verify(() => mockSupabase.sendMove(
            roomId: 'room-1',
            move: captureAny(named: 'move'),
          )).captured;

      expect(captured, hasLength(1));
      final move = captured.single as Map<String, dynamic>;
      expect(move['type'], 'bid');
      expect(move['player_id'], botId);
      // Critical regression: must be bid_value (snake_case), not bid.
      expect(move.containsKey('bid_value'), isTrue,
          reason: 'edge function reads data.bid_value');
      expect(move['bid_value'], isA<int>());
      final bid = move['bid_value'] as int;
      expect(bid, inInclusiveRange(0, 3));
      expect(move.containsKey('bid'), isFalse,
          reason: 'old key "bid" should not be emitted');
    });

    test('bot in playing phase emits {type: "playCard", player_id, card}',
        () async {
      final container = buildContainer(
        initialState: playingState(currentPlayerId: botId),
        bots: const [BotInfo(id: botId, difficulty: 'medium')],
      );
      addTearDown(container.dispose);

      container
          .read(botMoveControllerProvider)
          .startWatching(roomId: 'room-1');

      await Future<void>.delayed(const Duration(milliseconds: 900));

      final captured = verify(() => mockSupabase.sendMove(
            roomId: 'room-1',
            move: captureAny(named: 'move'),
          )).captured;

      expect(captured, hasLength(1));
      final move = captured.single as Map<String, dynamic>;
      expect(move['type'], 'playCard');
      expect(move['player_id'], botId);
      expect(move['card'], isA<Map>());
      final card = move['card'] as Map;
      expect(card['suit'], 'hearts');
      expect(card['rank'], 'ace');
    });

    test('non-bot turn during Oh Hell bidding does not send', () async {
      final container = buildContainer(
        initialState: biddingState(currentPlayerId: 'host'),
        bots: const [BotInfo(id: botId, difficulty: 'medium')],
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
  });
}
