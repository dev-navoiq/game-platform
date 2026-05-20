import 'package:game_core/game_core.dart';

import 'twenty_nine_rules.dart';

/// Registers Twenty-Nine with the provided [GameRegistry].
void registerTwentyNine(GameRegistry registry) {
  registry.register(
    GameDescriptor(
      id: 'twenty_nine',
      name: 'Twenty-Nine',
      minPlayers: TwentyNineRules().minPlayers,
      maxPlayers: TwentyNineRules().maxPlayers,
      category: GameCategory.cardGame,
    ),
  );
}
