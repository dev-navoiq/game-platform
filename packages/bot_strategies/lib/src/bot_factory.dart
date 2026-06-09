import 'core/difficulty.dart';
import 'core/personality.dart';
import 'card_games/twenty_nine_bot.dart';
import 'card_games/oh_hell_bot.dart';
import 'card_games/hearts_bot.dart';
import 'card_games/spades_bot.dart';
import 'card_games/bridge_bot.dart';
import 'board_games/chess_bot.dart';
import 'board_games/ludo_bot.dart';
import 'board_games/sequence_bot.dart';

/// Factory for creating game-specific bot players.
class BotFactory {
  static final List<String> _botNames = [
    'Alex',
    'Jordan',
    'Casey',
    'Morgan',
    'Riley',
    'Quinn',
    'Avery',
    'Blake',
    'Cameron',
    'Drew',
  ];

  static int _nameIndex = 0;

  static String _getNextName() {
    final name = _botNames[_nameIndex % _botNames.length];
    _nameIndex++;
    return name;
  }

  /// Reset the name counter (useful in tests).
  static void resetNames() => _nameIndex = 0;

  /// Create a bot for the given [gameType].
  ///
  /// Supported game types: `twenty_nine`, `oh_hell`, `hearts`, `spades`,
  /// `chess`, `ludo`, `sequence`.
  /// Returns a [TwentyNineBot], [OhHellBot], [ChessBot], etc. depending on
  /// [gameType]. The caller should downcast to the concrete bot type.
  static Object createBot({
    required String gameType,
    required String playerId,
    String? name,
    BotDifficulty difficulty = BotDifficulty.medium,
    BotPersonality personality = BotPersonality.balanced,
  }) {
    final botName = name ?? _getNextName();

    return switch (gameType) {
      'twenty_nine' => TwentyNineBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      'oh_hell' => OhHellBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      'hearts' => HeartsBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      'spades' => SpadesBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      'bridge' => BridgeBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      'chess' => ChessBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      'ludo' => LudoBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      'sequence' => SequenceBot(
          playerId: playerId,
          name: botName,
          difficulty: difficulty,
          personality: personality,
        ),
      _ => throw ArgumentError('Unknown game type: $gameType'),
    };
  }
}
