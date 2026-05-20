import 'package:game_core/game_core.dart';

import 'hearts_rules.dart';

/// Registers Hearts with the provided [GameRegistry].
void registerHearts(GameRegistry registry) {
  final rules = HeartsRules();
  registry.register(
    GameDescriptor(
      id: 'hearts',
      name: 'Hearts',
      minPlayers: rules.minPlayers,
      maxPlayers: rules.maxPlayers,
      category: GameCategory.cardGame,
    ),
  );
}
