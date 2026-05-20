/// AI players for all games — easy/medium/hard/expert difficulty.
/// All bot logic runs fully client-side (no network calls) for offline play.
library bot_strategies;

// Core framework
export 'src/core/bot_player.dart';
export 'src/core/difficulty.dart';
export 'src/core/personality.dart';
export 'src/core/think_time.dart';

// Card game bots
export 'src/card_games/twenty_nine_bot.dart';
export 'src/card_games/oh_hell_bot.dart';
export 'src/card_games/hearts_bot.dart';
export 'src/card_games/spades_bot.dart';

// Board game bots
export 'src/board_games/chess_bot.dart';
export 'src/board_games/ludo_bot.dart';
export 'src/board_games/sequence_bot.dart';

// Factory
export 'src/bot_factory.dart';
