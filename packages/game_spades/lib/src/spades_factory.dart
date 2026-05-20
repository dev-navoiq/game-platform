import 'package:game_core/game_core.dart';

import 'spades_rules.dart';

/// Registers Spades with the provided [GameRegistry].
void registerSpades(GameRegistry registry) {
  final rules = SpadesRules();
  registry.register(
    GameDescriptor(
      id: 'spades',
      name: 'Spades',
      minPlayers: rules.minPlayers,
      maxPlayers: rules.maxPlayers,
      category: GameCategory.cardGame,
    ),
  );
}
