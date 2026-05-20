# Game Screens

> **Prompt 11 of 18** | Implements game-specific UI screens for card games and board games with responsive layouts.

## Overview

This prompt creates the gameplay screens for all game types, integrating the glass UI components, animation system, and game state management.

---

## Directory Structure

```
lib/features/game/
├── data/
│   └── game_repository.dart
├── presentation/
│   ├── game_screen.dart            # Main game shell
│   ├── providers/
│   │   ├── game_providers.dart     # Game state providers
│   │   └── session_providers.dart  # Session management
│   ├── screens/
│   │   ├── card_game_screen.dart   # Card game layout
│   │   ├── chess_screen.dart       # Chess board layout
│   │   ├── ludo_screen.dart        # Ludo board layout
│   │   └── sequence_screen.dart    # Sequence board layout
│   └── widgets/
│       ├── game_table.dart         # Table background
│       ├── player_position.dart    # Player seat widget
│       ├── card_hand.dart          # Player's hand
│       ├── card_fan.dart           # Fan layout for cards
│       ├── trick_area.dart         # Current trick display
│       ├── score_display.dart      # Score overlay
│       ├── turn_indicator.dart     # Whose turn
│       ├── timer_widget.dart       # Turn timer
│       ├── game_chat.dart          # In-game chat
│       ├── game_actions.dart       # Action buttons
│       └── game_over_dialog.dart   # End game modal
```

---

## Game Repository

```dart
// lib/features/game/data/game_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_core/game_core.dart';

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.watch(supabaseProvider));
});

class GameRepository {
  final SupabaseClient _supabase;
  RealtimeChannel? _gameChannel;

  GameRepository(this._supabase);

  /// Subscribe to game state updates
  Stream<Map<String, dynamic>> subscribeToGame(String gameId) {
    _gameChannel = _supabase.channel('game:$gameId');

    return _gameChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'game_sessions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: gameId,
        ),
        callback: (payload) {},
      )
      .subscribe()
      .asStream()
      .map((_) => {});
  }

  /// Get current game state
  Future<Map<String, dynamic>> getGameState(String gameId) async {
    final response = await _supabase
      .from('game_sessions')
      .select('*, room:rooms(*)')
      .eq('id', gameId)
      .single();
    return response;
  }

  /// Submit a move
  Future<void> submitMove(String gameId, Map<String, dynamic> move) async {
    // Validate move server-side via edge function
    await _supabase.functions.invoke('validate-move', body: {
      'gameId': gameId,
      'move': move,
    });
  }

  /// Send chat message
  Future<void> sendMessage(String roomId, String message) async {
    await _supabase.from('chat_messages').insert({
      'room_id': roomId,
      'content': message,
    });
  }

  /// Leave game
  Future<void> leaveGame(String gameId) async {
    await _supabase.from('game_sessions').update({
      'status': 'abandoned',
    }).eq('id', gameId);
  }

  /// Cleanup
  void dispose() {
    _gameChannel?.unsubscribe();
  }
}
```

---

## Game Providers

```dart
// lib/features/game/presentation/providers/game_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';
import 'package:game_chess/game_chess.dart';
import 'package:game_ludo/game_ludo.dart';

import '../../data/game_repository.dart';

/// Current game ID being played
final currentGameIdProvider = StateProvider<String?>((ref) => null);

/// Game state stream
final gameStateStreamProvider = StreamProvider.family<GameState, String>((ref, gameId) {
  final repository = ref.watch(gameRepositoryProvider);
  return repository.subscribeToGame(gameId).asyncMap((_) async {
    final data = await repository.getGameState(gameId);
    return _parseGameState(data);
  });
});

/// Current game state (cached)
final gameStateProvider = Provider.family<AsyncValue<GameState>, String>((ref, gameId) {
  return ref.watch(gameStateStreamProvider(gameId));
});

/// Game rules based on game type
final gameRulesProvider = Provider.family<GameRules, String>((ref, gameType) {
  switch (gameType) {
    case 'twenty_nine':
      return TwentyNineRules(TwentyNineConfig.standard());
    case 'chess':
      return ChessRules(ChessConfig.rapid());
    case 'ludo':
      return LudoRules(LudoConfig(variant: LudoVariant.classic, playerCount: 4));
    default:
      throw ArgumentError('Unknown game type: $gameType');
  }
});

/// Valid moves for current player
final validMovesProvider = Provider.family<List<GameMove>, String>((ref, gameId) {
  final stateAsync = ref.watch(gameStateProvider(gameId));
  final currentUser = ref.watch(currentUserProvider);

  return stateAsync.when(
    data: (state) {
      final gameType = state.runtimeType.toString().toLowerCase();
      final rules = ref.read(gameRulesProvider(gameType));
      if (currentUser == null) return [];
      return rules.getValidMoves(state, currentUser.id);
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Selected card (for card games)
final selectedCardProvider = StateProvider<PlayingCard?>((ref) => null);

/// Selected position (for board games)
final selectedPositionProvider = StateProvider<dynamic>((ref) => null);

/// Is it current player's turn?
final isMyTurnProvider = Provider.family<bool, String>((ref, gameId) {
  final stateAsync = ref.watch(gameStateProvider(gameId));
  final currentUser = ref.watch(currentUserProvider);

  return stateAsync.when(
    data: (state) {
      if (currentUser == null) return false;
      // Check if current player's turn based on game type
      return true; // Placeholder
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

GameState _parseGameState(Map<String, dynamic> data) {
  final gameType = data['game_type'] as String;
  final stateJson = data['state'] as Map<String, dynamic>;

  switch (gameType) {
    case 'twenty_nine':
      return TwentyNineState.fromJson(stateJson);
    case 'chess':
      return ChessState.fromJson(stateJson);
    case 'ludo':
      return LudoState.fromJson(stateJson);
    default:
      throw ArgumentError('Unknown game type: $gameType');
  }
}
```

---

## Main Game Screen

```dart
// lib/features/game/presentation/game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/game_providers.dart';
import 'screens/card_game_screen.dart';
import 'screens/chess_screen.dart';
import 'screens/ludo_screen.dart';
import 'screens/sequence_screen.dart';
import 'widgets/game_chat.dart';
import 'widgets/game_over_dialog.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../core/theme/colors.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  bool _showChat = false;
  late final AnimationController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameStateAsync = ref.watch(gameStateStreamProvider(widget.gameId));

    return Scaffold(
      body: gameStateAsync.when(
        data: (state) => _buildGameUI(context, state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorUI(context, error),
      ),
    );
  }

  Widget _buildGameUI(BuildContext context, GameState state) {
    // Check for game over
    if (state.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameOverDialog(context, state);
      });
    }

    final gameType = _getGameType(state);

    return Stack(
      children: [
        // Game background
        _buildBackground(gameType),

        // Game content
        SafeArea(
          child: _buildGameContent(context, state, gameType),
        ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTopBar(context, state),
        ),

        // Chat overlay
        AnimatedBuilder(
          animation: _chatController,
          builder: (context, child) {
            return Positioned(
              right: 0,
              top: 100,
              bottom: 100,
              width: 300 * _chatController.value,
              child: Opacity(
                opacity: _chatController.value,
                child: const GameChat(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBackground(String gameType) {
    final skinId = ref.watch(selectedRoomSkinProvider);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/rooms/$skinId/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.3),
      ),
    );
  }

  Widget _buildGameContent(BuildContext context, GameState state, String gameType) {
    switch (gameType) {
      case 'twenty_nine':
      case 'oh_hell':
      case 'hearts':
        return CardGameScreen(state: state as dynamic);
      case 'chess':
        return ChessScreen(state: state as ChessState);
      case 'ludo':
        return LudoScreen(state: state as LudoState);
      case 'sequence':
        return SequenceScreen(state: state as SequenceState);
      default:
        return Center(child: Text('Unknown game type: $gameType'));
    }
  }

  Widget _buildTopBar(BuildContext context, GameState state) {
    return GlassContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _confirmLeave(context),
          ),

          const Spacer(),

          // Score display
          _buildScoreChip(state),

          const Spacer(),

          // Chat toggle
          IconButton(
            icon: Icon(
              _showChat ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: Colors.white,
            ),
            onPressed: _toggleChat,
          ),

          // Settings
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(GameState state) {
    // Display score based on game type
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: 20,
      child: const Text(
        'Score: 0',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getGameType(GameState state) {
    return state.runtimeType.toString().replaceAll('State', '').toLowerCase();
  }

  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
      if (_showChat) {
        _chatController.forward();
      } else {
        _chatController.reverse();
      }
    });
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text('You will forfeit if you leave now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(gameRepositoryProvider).leaveGame(widget.gameId);
      context.go('/home');
    }
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const GameSettingsSheet(),
    );
  }

  void _showGameOverDialog(BuildContext context, GameState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GameOverDialog(state: state),
    );
  }

  Widget _buildErrorUI(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }
}

class GameSettingsSheet extends StatelessWidget {
  const GameSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Game Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Sound Effects'),
            value: true,
            onChanged: (value) {},
          ),
          SwitchListTile(
            title: const Text('Animations'),
            value: true,
            onChanged: (value) {},
          ),
          SwitchListTile(
            title: const Text('Show Timer'),
            value: true,
            onChanged: (value) {},
          ),
        ],
      ),
    );
  }
}
```

---

## Card Game Screen

```dart
// lib/features/game/presentation/screens/card_game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../providers/game_providers.dart';
import '../widgets/player_position.dart';
import '../widgets/card_hand.dart';
import '../widgets/trick_area.dart';
import '../widgets/turn_indicator.dart';
import '../widgets/timer_widget.dart';
import '../../../../shared/widgets/playing_card.dart';

class CardGameScreen extends ConsumerWidget {
  final GameState state;

  const CardGameScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isLandscape) {
          return _buildLandscapeLayout(context, ref, constraints);
        }
        return _buildPortraitLayout(context, ref, constraints);
      },
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    WidgetRef ref,
    BoxConstraints constraints,
  ) {
    final playerIds = state.playerIds;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final myIndex = playerIds.indexOf(currentUserId ?? '');

    // Arrange players: bottom (me), left, top, right
    final orderedPlayers = _reorderPlayers(playerIds, myIndex);

    return Column(
      children: [
        const SizedBox(height: 80), // Top bar space

        // Top player
        if (orderedPlayers.length > 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PlayerPosition(
              playerId: orderedPlayers[2],
              position: PlayerSeatPosition.top,
              state: state,
            ),
          ),

        // Middle area: left player, trick, right player
        Expanded(
          child: Row(
            children: [
              // Left player
              if (orderedPlayers.length > 1)
                SizedBox(
                  width: 80,
                  child: PlayerPosition(
                    playerId: orderedPlayers[1],
                    position: PlayerSeatPosition.left,
                    state: state,
                    isVertical: true,
                  ),
                ),

              // Trick area
              Expanded(
                child: TrickArea(state: state),
              ),

              // Right player
              if (orderedPlayers.length > 3)
                SizedBox(
                  width: 80,
                  child: PlayerPosition(
                    playerId: orderedPlayers[3],
                    position: PlayerSeatPosition.right,
                    state: state,
                    isVertical: true,
                  ),
                ),
            ],
          ),
        ),

        // My hand
        Container(
          height: 180,
          padding: const EdgeInsets.only(bottom: 16),
          child: CardHand(
            playerId: orderedPlayers[0],
            state: state,
            onCardTap: (card) => _handleCardTap(ref, card),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    WidgetRef ref,
    BoxConstraints constraints,
  ) {
    final playerIds = state.playerIds;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final myIndex = playerIds.indexOf(currentUserId ?? '');
    final orderedPlayers = _reorderPlayers(playerIds, myIndex);

    return Row(
      children: [
        // Left sidebar: left player + my hand (vertical)
        SizedBox(
          width: 120,
          child: Column(
            children: [
              if (orderedPlayers.length > 1)
                Expanded(
                  child: PlayerPosition(
                    playerId: orderedPlayers[1],
                    position: PlayerSeatPosition.left,
                    state: state,
                    isVertical: true,
                  ),
                ),
            ],
          ),
        ),

        // Center: top, trick, bottom
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: 60), // Top bar

              // Top player
              if (orderedPlayers.length > 2)
                PlayerPosition(
                  playerId: orderedPlayers[2],
                  position: PlayerSeatPosition.top,
                  state: state,
                ),

              // Trick area
              Expanded(
                child: TrickArea(state: state),
              ),

              // My hand
              Container(
                height: 140,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CardHand(
                  playerId: orderedPlayers[0],
                  state: state,
                  onCardTap: (card) => _handleCardTap(ref, card),
                ),
              ),
            ],
          ),
        ),

        // Right sidebar: right player
        SizedBox(
          width: 120,
          child: Column(
            children: [
              if (orderedPlayers.length > 3)
                Expanded(
                  child: PlayerPosition(
                    playerId: orderedPlayers[3],
                    position: PlayerSeatPosition.right,
                    state: state,
                    isVertical: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _reorderPlayers(List<String> players, int myIndex) {
    if (myIndex < 0) return players;
    return [
      ...players.sublist(myIndex),
      ...players.sublist(0, myIndex),
    ];
  }

  void _handleCardTap(WidgetRef ref, PlayingCard card) {
    final selectedCard = ref.read(selectedCardProvider);

    if (selectedCard == card) {
      // Play the card
      _playCard(ref, card);
    } else {
      // Select the card
      ref.read(selectedCardProvider.notifier).state = card;
    }
  }

  Future<void> _playCard(WidgetRef ref, PlayingCard card) async {
    final gameId = state.gameId;
    final repository = ref.read(gameRepositoryProvider);

    await repository.submitMove(gameId, {
      'type': 'play_card',
      'card': card.toJson(),
    });

    ref.read(selectedCardProvider.notifier).state = null;
  }
}

enum PlayerSeatPosition { top, bottom, left, right }
```

---

## Card Hand Widget

```dart
// lib/features/game/presentation/widgets/card_hand.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../providers/game_providers.dart';
import '../../../../shared/widgets/playing_card.dart';

class CardHand extends ConsumerWidget {
  final String playerId;
  final GameState state;
  final void Function(PlayingCard card)? onCardTap;

  const CardHand({
    super.key,
    required this.playerId,
    required this.state,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = _getPlayerCards();
    final selectedCard = ref.watch(selectedCardProvider);
    final validMoves = ref.watch(validMovesProvider(state.gameId));

    final playableCards = _getPlayableCards(validMoves);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = 70.0;
        final totalWidth = constraints.maxWidth;
        final overlap = _calculateOverlap(cards.length, cardWidth, totalWidth);

        return Center(
          child: SizedBox(
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < cards.length; i++)
                  _buildCard(
                    context,
                    cards[i],
                    i,
                    cards.length,
                    overlap,
                    selectedCard == cards[i],
                    playableCards.contains(cards[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PlayingCard> _getPlayerCards() {
    // Extract cards from state based on game type
    // This would need type-specific handling
    return [];
  }

  Set<PlayingCard> _getPlayableCards(List<GameMove> moves) {
    // Extract playable cards from valid moves
    return {};
  }

  double _calculateOverlap(int cardCount, double cardWidth, double totalWidth) {
    if (cardCount <= 1) return 0;
    final requiredWidth = cardCount * cardWidth;
    if (requiredWidth <= totalWidth) return 0;
    return (requiredWidth - totalWidth) / (cardCount - 1);
  }

  Widget _buildCard(
    BuildContext context,
    PlayingCard card,
    int index,
    int total,
    double overlap,
    bool isSelected,
    bool isPlayable,
  ) {
    final centerIndex = (total - 1) / 2;
    final offset = index - centerIndex;

    // Calculate fan rotation
    final rotation = offset * 3 * (3.14159 / 180); // 3 degrees per card

    // Calculate horizontal position
    final xOffset = offset * (70 - overlap);

    // Lift selected card
    final yOffset = isSelected ? -20.0 : 0.0;

    return Positioned(
      left: MediaQuery.of(context).size.width / 2 + xOffset - 35,
      child: GestureDetector(
        onTap: isPlayable ? () => onCardTap?.call(card) : null,
        child: Transform.translate(
          offset: Offset(0, yOffset),
          child: Transform.rotate(
            angle: rotation,
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: PlayingCardWidget(
                card: card,
                width: 70,
                isHighlighted: isSelected,
                isDisabled: !isPlayable,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Trick Area Widget

```dart
// lib/features/game/presentation/widgets/trick_area.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../../../../shared/widgets/playing_card.dart';
import '../../../../shared/widgets/card_animations.dart';

class TrickArea extends ConsumerWidget {
  final GameState state;

  const TrickArea({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trickCards = _getTrickCards();

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Table center decoration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
          ),

          // Cards in trick
          for (final entry in trickCards.entries)
            _buildPlayedCard(entry.key, entry.value),
        ],
      ),
    );
  }

  Map<String, PlayingCard> _getTrickCards() {
    // Extract current trick cards from state
    return {};
  }

  Widget _buildPlayedCard(String playerId, PlayingCard card) {
    // Position based on player position
    final offset = _getCardOffset(playerId);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: offset.dx,
      top: offset.dy,
      child: CardPlayAnimation(
        child: PlayingCardWidget(
          card: card,
          width: 60,
        ),
      ),
    );
  }

  Offset _getCardOffset(String playerId) {
    // Calculate position based on player seat
    // This would use the player order to determine placement
    return Offset.zero;
  }
}
```

---

## Player Position Widget

```dart
// lib/features/game/presentation/widgets/player_position.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';

import '../screens/card_game_screen.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/player_avatar.dart';
import '../../../../core/theme/colors.dart';

class PlayerPosition extends ConsumerWidget {
  final String playerId;
  final PlayerSeatPosition position;
  final GameState state;
  final bool isVertical;

  const PlayerPosition({
    super.key,
    required this.playerId,
    required this.position,
    required this.state,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentTurn = _isPlayerTurn();
    final playerInfo = _getPlayerInfo();

    return GlassContainer(
      padding: const EdgeInsets.all(8),
      borderRadius: 12,
      border: isCurrentTurn
        ? Border.all(color: AppColors.primary, width: 2)
        : null,
      child: isVertical
        ? _buildVerticalLayout(playerInfo, isCurrentTurn)
        : _buildHorizontalLayout(playerInfo, isCurrentTurn),
    );
  }

  Widget _buildHorizontalLayout(Map<String, dynamic> info, bool isCurrentTurn) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Stack(
          children: [
            PlayerAvatar(
              userId: playerId,
              size: 40,
            ),
            if (isCurrentTurn)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),

        // Name and score
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              info['name'] ?? 'Player',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              'Score: ${info['score'] ?? 0}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),

        // Turn indicator
        if (isCurrentTurn) ...[
          const SizedBox(width: 8),
          _buildTurnIndicator(),
        ],
      ],
    );
  }

  Widget _buildVerticalLayout(Map<String, dynamic> info, bool isCurrentTurn) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        PlayerAvatar(
          userId: playerId,
          size: 36,
        ),
        const SizedBox(height: 4),

        // Name
        Text(
          info['name'] ?? 'Player',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          overflow: TextOverflow.ellipsis,
        ),

        // Card count (for opponents)
        if (position != PlayerSeatPosition.bottom)
          _buildCardCount(info['cardCount'] ?? 0),
      ],
    );
  }

  Widget _buildCardCount(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.style,
          size: 12,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTurnIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withOpacity(value),
          ),
        );
      },
    );
  }

  bool _isPlayerTurn() {
    // Check if this player's turn
    return false; // Placeholder
  }

  Map<String, dynamic> _getPlayerInfo() {
    // Get player info from state
    return {
      'name': 'Player',
      'score': 0,
      'cardCount': 8,
    };
  }
}
```

---

## Chess Screen

```dart
// lib/features/game/presentation/screens/chess_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_chess/game_chess.dart';

import '../providers/game_providers.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../core/theme/colors.dart';

class ChessScreen extends ConsumerStatefulWidget {
  final ChessState state;

  const ChessScreen({super.key, required this.state});

  @override
  ConsumerState<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends ConsumerState<ChessScreen> {
  ChessSquare? _selectedSquare;
  Set<ChessSquare> _validMoveSquares = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80), // Top bar space

        // Captured pieces (opponent)
        _buildCapturedPieces(PieceColor.black),

        // Chess board
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildBoard(),
            ),
          ),
        ),

        // Captured pieces (me)
        _buildCapturedPieces(PieceColor.white),

        const SizedBox(height: 16),

        // Move history
        _buildMoveHistory(),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBoard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = 7 - (index ~/ 8);
            final col = index % 8;
            final square = ChessSquare(col, row);
            return _buildSquare(square);
          },
        ),
      ),
    );
  }

  Widget _buildSquare(ChessSquare square) {
    final piece = widget.state.board.pieceAt(square);
    final isLight = square.isLightSquare;
    final isSelected = square == _selectedSquare;
    final isValidMove = _validMoveSquares.contains(square);
    final isLastMove = _isLastMoveSquare(square);

    return GestureDetector(
      onTap: () => _handleSquareTap(square),
      child: Container(
        decoration: BoxDecoration(
          color: _getSquareColor(isLight, isSelected, isValidMove, isLastMove),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Valid move indicator
            if (isValidMove && piece == null)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.2),
                ),
              ),

            // Capture indicator
            if (isValidMove && piece != null)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withOpacity(0.2),
                    width: 3,
                  ),
                ),
              ),

            // Piece
            if (piece != null)
              Text(
                piece.symbol,
                style: const TextStyle(fontSize: 32),
              ),

            // Coordinates
            if (square.rank == 0)
              Positioned(
                bottom: 2,
                right: 4,
                child: Text(
                  square.notation[0],
                  style: TextStyle(
                    fontSize: 10,
                    color: isLight ? Colors.brown : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            if (square.file == 0)
              Positioned(
                top: 2,
                left: 4,
                child: Text(
                  '${square.rank + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isLight ? Colors.brown : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getSquareColor(bool isLight, bool isSelected, bool isValidMove, bool isLastMove) {
    if (isSelected) {
      return Colors.yellow.withOpacity(0.5);
    }
    if (isLastMove) {
      return Colors.green.withOpacity(0.3);
    }
    if (isLight) {
      return const Color(0xFFF0D9B5);
    }
    return const Color(0xFFB58863);
  }

  bool _isLastMoveSquare(ChessSquare square) {
    if (widget.state.moveHistory.isEmpty) return false;
    final lastMove = widget.state.moveHistory.last;
    return lastMove.from == square || lastMove.to == square;
  }

  void _handleSquareTap(ChessSquare square) {
    final piece = widget.state.board.pieceAt(square);

    if (_selectedSquare != null && _validMoveSquares.contains(square)) {
      // Make move
      _makeMove(_selectedSquare!, square);
      setState(() {
        _selectedSquare = null;
        _validMoveSquares = {};
      });
    } else if (piece != null && piece.color == widget.state.activeColor) {
      // Select piece
      setState(() {
        _selectedSquare = square;
        _validMoveSquares = _getValidMoveSquares(square);
      });
    } else {
      // Deselect
      setState(() {
        _selectedSquare = null;
        _validMoveSquares = {};
      });
    }
  }

  Set<ChessSquare> _getValidMoveSquares(ChessSquare from) {
    final validMoves = ref.read(validMovesProvider(widget.state.gameId));
    return validMoves
      .whereType<ChessMove>()
      .where((m) => m.from == from)
      .map((m) => m.to)
      .toSet();
  }

  Future<void> _makeMove(ChessSquare from, ChessSquare to) async {
    final repository = ref.read(gameRepositoryProvider);
    await repository.submitMove(widget.state.gameId, {
      'from': from.notation,
      'to': to.notation,
    });
  }

  Widget _buildCapturedPieces(PieceColor color) {
    // Display captured pieces
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        children: [
          // Placeholder for captured pieces
        ],
      ),
    );
  }

  Widget _buildMoveHistory() {
    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: widget.state.moveHistory.length,
          itemBuilder: (context, index) {
            final move = widget.state.moveHistory[index];
            final moveNumber = (index ~/ 2) + 1;
            final isWhite = index % 2 == 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isWhite
                  ? '$moveNumber. ${move.toAlgebraic(widget.state.board)}'
                  : move.toAlgebraic(widget.state.board),
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

---

## Ludo Screen

```dart
// lib/features/game/presentation/screens/ludo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_ludo/game_ludo.dart';

import '../providers/game_providers.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../core/theme/colors.dart';

class LudoScreen extends ConsumerStatefulWidget {
  final LudoState state;

  const LudoScreen({super.key, required this.state});

  @override
  ConsumerState<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends ConsumerState<LudoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _diceController;
  int? _rollingDice;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 80),

        // Player info row
        _buildPlayerInfoRow(),

        // Board
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _buildBoard(),
            ),
          ),
        ),

        // Dice and actions
        _buildDiceArea(),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPlayerInfoRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: widget.state.playerColors.entries.map((entry) {
          final isCurrentTurn = widget.state.currentPlayerId == entry.key;
          return _buildPlayerChip(entry.key, entry.value, isCurrentTurn);
        }).toList(),
      ),
    );
  }

  Widget _buildPlayerChip(String playerId, LudoColor color, bool isCurrentTurn) {
    final colorValue = _getLudoColor(color);

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 20,
      border: isCurrentTurn
        ? Border.all(color: colorValue, width: 2)
        : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: colorValue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Player ${widget.state.playerIds.indexOf(playerId) + 1}',
            style: TextStyle(
              color: Colors.white,
              fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: CustomPaint(
        painter: LudoBoardPainter(),
        child: _buildTokens(),
      ),
    );
  }

  Widget _buildTokens() {
    return Stack(
      children: widget.state.playerTokens.entries.expand((entry) {
        return entry.value.map((token) => _buildToken(token));
      }).toList(),
    );
  }

  Widget _buildToken(LudoToken token) {
    final position = _calculateTokenPosition(token);
    final color = _getLudoColor(token.color);
    final isMovable = _isTokenMovable(token);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      left: position.dx - 12,
      top: position.dy - 12,
      child: GestureDetector(
        onTap: isMovable ? () => _handleTokenTap(token) : null,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isMovable
            ? const Center(
                child: Icon(
                  Icons.touch_app,
                  size: 12,
                  color: Colors.white,
                ),
              )
            : null,
        ),
      ),
    );
  }

  Offset _calculateTokenPosition(LudoToken token) {
    // Calculate pixel position based on board position
    // This would use the token's LudoPosition to determine screen coordinates
    return Offset.zero; // Placeholder
  }

  bool _isTokenMovable(LudoToken token) {
    final validMoves = ref.read(validMovesProvider(widget.state.gameId));
    return validMoves.any((m) => m is LudoMoveToken && m.tokenId == token.id);
  }

  Widget _buildDiceArea() {
    final diceRoll = widget.state.diceRoll;
    final canRoll = widget.state.diceRoll == null &&
                    widget.state.currentPlayerId == ref.watch(currentUserProvider)?.id;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dice display
          GestureDetector(
            onTap: canRoll ? _rollDice : null,
            child: AnimatedBuilder(
              animation: _diceController,
              builder: (context, child) {
                final displayValue = _rollingDice ?? diceRoll ?? 1;
                return Transform.rotate(
                  angle: _diceController.value * 4 * 3.14159,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        canRoll ? '?' : '$displayValue',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 16),

          // Roll button
          if (canRoll)
            ElevatedButton(
              onPressed: _rollDice,
              child: const Text('Roll'),
            ),
        ],
      ),
    );
  }

  Future<void> _rollDice() async {
    // Animate dice
    _diceController.repeat();
    setState(() {
      _rollingDice = 1;
    });

    // Simulate rolling animation
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        _rollingDice = (i % 6) + 1;
      });
    }

    _diceController.stop();
    setState(() {
      _rollingDice = null;
    });

    // Submit roll
    final repository = ref.read(gameRepositoryProvider);
    await repository.submitMove(widget.state.gameId, {
      'type': 'roll',
    });
  }

  Future<void> _handleTokenTap(LudoToken token) async {
    final repository = ref.read(gameRepositoryProvider);
    await repository.submitMove(widget.state.gameId, {
      'type': 'move',
      'tokenId': token.id,
    });
  }

  Color _getLudoColor(LudoColor color) {
    switch (color) {
      case LudoColor.red: return AppColors.player1;
      case LudoColor.blue: return AppColors.player2;
      case LudoColor.green: return AppColors.player3;
      case LudoColor.yellow: return AppColors.player4;
    }
  }
}

class LudoBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw Ludo board layout
    // This would include:
    // - Four colored home areas (corners)
    // - Main track
    // - Home stretches
    // - Safe squares
    // - Center finish area
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

---

## Game Over Dialog

```dart
// lib/features/game/presentation/widgets/game_over_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:game_core/game_core.dart';
import 'package:confetti/confetti.dart';

import '../../../../shared/widgets/glass_container.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/audio_service.dart';

class GameOverDialog extends ConsumerStatefulWidget {
  final GameState state;

  const GameOverDialog({super.key, required this.state});

  @override
  ConsumerState<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends ConsumerState<GameOverDialog> {
  late ConfettiController _confettiController;
  bool _isWinner = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _checkWinner();
  }

  void _checkWinner() {
    final currentUser = ref.read(currentUserProvider);
    // Check if current user is winner
    _isWinner = true; // Placeholder

    if (_isWinner) {
      _confettiController.play();
      ref.read(audioServiceProvider).playGameWin();
    } else {
      ref.read(audioServiceProvider).playGameLose();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dialog
        Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  _isWinner ? 'Victory!' : 'Game Over',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _isWinner ? AppColors.success : Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Result icon
                Icon(
                  _isWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                  size: 80,
                  color: _isWinner ? Colors.amber : Colors.grey,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  _isWinner
                    ? 'Congratulations! You won the game!'
                    : 'Better luck next time!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Stats
                _buildStats(),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Home'),
                    ),
                    ElevatedButton(
                      onPressed: _playAgain,
                      child: const Text('Play Again'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Confetti
        if (_isWinner)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.1,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildStatRow('Duration', '15:32'),
          _buildStatRow('Points', '+25'),
          _buildStatRow('XP', '+150'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _playAgain() {
    // Navigate to create new game with same settings
    context.go('/lobby/${widget.state.gameId}');
  }
}
```

---

## Game Chat Widget

```dart
// lib/features/game/presentation/widgets/game_chat.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/glass_container.dart';

class GameChat extends ConsumerStatefulWidget {
  const GameChat({super.key});

  @override
  ConsumerState<GameChat> createState() => _GameChatState();
}

class _GameChatState extends ConsumerState<GameChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: 0, // Placeholder
              itemBuilder: (context, index) {
                return _buildMessage(
                  'Player',
                  'Hello!',
                  DateTime.now(),
                );
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String sender, String content, DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                sender,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    // Send message via repository
    _controller.clear();
  }
}
```

---

## Integration Notes

1. **Responsive Layouts**: All screens support both portrait and landscape
2. **Real-time Updates**: Game state streams from Supabase Realtime
3. **Animations**: Cards and pieces animate smoothly using the animation system
4. **Audio**: Sound effects play on card deals, moves, and game events
5. **Chat**: In-game chat available via slide-out panel
6. **Validation**: All moves validated server-side before applying
