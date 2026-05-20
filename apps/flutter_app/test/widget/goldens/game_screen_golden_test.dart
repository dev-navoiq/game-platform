import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_app/features/game/screens/game_screen.dart';
import 'package:flutter_app/features/lobby/screens/lobby_screen.dart';
import 'package:flutter_app/features/game/providers/game_provider.dart';
import 'package:flutter_app/core/services/supabase_service.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';
import 'package:mocktail/mocktail.dart';

class _MockSupabaseService extends Mock implements SupabaseService {}

/// Builds the game screen with a stubbed state so goldens are stable.
Widget _gameScreen(TwentyNineState? state) {
  return ProviderScope(
    overrides: [
      if (state != null)
        gameStateProvider.overrideWith((ref) {
          final notifier = GameNotifier(_MockSupabaseService());
          notifier.updateState(state);
          return notifier;
        }),
    ],
    child: const MaterialApp(
      home: GameScreen(roomId: 'golden-test-room'),
    ),
  );
}

TwentyNineState _sampleState() {
  return TwentyNineState(
    phase: GamePhase.playing,
    currentPlayerId: 'me',
    hands: {
      'me': Hand([
        PlayingCard(Suit.hearts, Rank.jack),
        PlayingCard(Suit.spades, Rank.nine),
        PlayingCard(Suit.clubs, Rank.ace),
        PlayingCard(Suit.diamonds, Rank.ten),
      ]),
      'bot-1': Hand([PlayingCard(Suit.hearts, Rank.king)]),
      'bot-2': Hand([PlayingCard(Suit.spades, Rank.queen)]),
      'bot-3': Hand([PlayingCard(Suit.clubs, Rank.eight)]),
    },
    currentTrick: [],
    trumpSuit: Suit.spades,
    trumpRevealed: true,
    currentBid: 18,
    bidderId: 'bot-1',
    trumpSelector: 'bot-3',
    dealerIndex: 0,
    playerOrder: ['me', 'bot-1', 'bot-2', 'bot-3'],
    sessionScores: {0: 2, 1: 1},
  );
}

void main() {
  group('GameScreen Golden Tests', () {
    testGoldens('game screen — playing phase', (tester) async {
      await tester.pumpWidgetBuilder(
        _gameScreen(_sampleState()),
        surfaceSize: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'game_screen_playing');
    });

    testGoldens('game screen — responsive across device sizes', (tester) async {
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices: [
          Device.phone,
          Device.iphone11,
          Device.tabletPortrait,
          Device.tabletLandscape,
        ])
        ..addScenario(
          widget: ProviderScope(
            overrides: [
              gameStateProvider.overrideWith((ref) {
                final notifier = GameNotifier(_MockSupabaseService());
                notifier.updateState(_sampleState());
                return notifier;
              }),
            ],
            child: const GameScreen(roomId: 'golden-test-room'),
          ),
          name: 'game_screen',
        );

      await tester.pumpDeviceBuilder(builder);
      await screenMatchesGolden(tester, 'game_screen_responsive');
    });

    testGoldens('lobby screen — responsive across device sizes', (tester) async {
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices: [
          Device.phone,
          Device.iphone11,
          Device.tabletPortrait,
          Device.tabletLandscape,
        ])
        ..addScenario(
          widget: const ProviderScope(child: LobbyScreen()),
          name: 'lobby_screen',
        );

      await tester.pumpDeviceBuilder(builder);
      await screenMatchesGolden(tester, 'lobby_screen_responsive');
    });
  });
}
