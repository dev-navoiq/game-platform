import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_app/features/game/screens/game_screen.dart';
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

class MockSupabaseService extends Mock implements SupabaseService {}
class MockGameNotifier extends Mock implements GameNotifier {}

Widget buildGameScreen({
  required String roomId,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: GameScreen(roomId: roomId),
    ),
  );
}

void main() {
  group('GameScreen', () {
    testWidgets('shows loading indicator while game state loads', (tester) async {
      await tester.pumpWidget(buildGameScreen(
        roomId: 'test-room',
        overrides: [
          gameStateProvider.overrideWith((ref) => GameNotifier(MockSupabaseService())),
        ],
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows game table when state is loaded', (tester) async {
      final mockState = _buildPlayingState();
      await tester.pumpWidget(buildGameScreen(
        roomId: 'test-room',
        overrides: [
          gameStateProvider.overrideWith((ref) {
            final notifier = GameNotifier(MockSupabaseService());
            notifier.updateState(mockState);
            return notifier;
          }),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('game-table')), findsOneWidget);
    });

    testWidgets('shows player hand area', (tester) async {
      final mockState = _buildPlayingState();
      await tester.pumpWidget(buildGameScreen(
        roomId: 'test-room',
        overrides: [
          gameStateProvider.overrideWith((ref) {
            final notifier = GameNotifier(MockSupabaseService());
            notifier.updateState(mockState);
            return notifier;
          }),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-hand')), findsOneWidget);
    });

    testWidgets('shows score display in HUD', (tester) async {
      final mockState = _buildPlayingState();
      await tester.pumpWidget(buildGameScreen(
        roomId: 'test-room',
        overrides: [
          gameStateProvider.overrideWith((ref) {
            final notifier = GameNotifier(MockSupabaseService());
            notifier.updateState(mockState);
            return notifier;
          }),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('score-display')), findsOneWidget);
    });

    testWidgets('shows error screen on null game state after timeout', (tester) async {
      await tester.pumpWidget(buildGameScreen(
        roomId: 'bad-room',
        overrides: [
          gameStateProvider.overrideWith((ref) => GameNotifier(MockSupabaseService())),
        ],
      ));
      await tester.pump(const Duration(seconds: 15));
      // Should show some error / fallback UI
      expect(find.byKey(const Key('game-error')), findsOneWidget);
    });
  });
}

TwentyNineState _buildPlayingState() {
  return TwentyNineState(
    phase: GamePhase.playing,
    currentPlayerId: 'local-user',
    hands: {
      'local-user': Hand([
        PlayingCard(Suit.hearts, Rank.ace),
        PlayingCard(Suit.spades, Rank.jack),
        PlayingCard(Suit.clubs, Rank.nine),
      ]),
      'bot-1': Hand([PlayingCard(Suit.diamonds, Rank.ten)]),
      'bot-2': Hand([PlayingCard(Suit.hearts, Rank.king)]),
      'bot-3': Hand([PlayingCard(Suit.clubs, Rank.seven)]),
    },
    currentTrick: [],
    trumpSuit: Suit.spades,
    trumpRevealed: true,
    currentBid: 16,
    bidderId: 'bot-1',
    trumpSelector: 'bot-3',
    dealerIndex: 0,
    playerOrder: ['local-user', 'bot-1', 'bot-2', 'bot-3'],
    sessionScores: {0: 1, 1: 0},
  );
}
