import 'package:game_core/game_core.dart';

import 'oh_hell_rules.dart';

/// Registers Oh Hell with the provided [GameRegistry].
void registerOhHell(GameRegistry registry) {
  final rules = OhHellRules();
  registry.register(
    GameDescriptor(
      id: 'oh_hell',
      name: 'Oh Hell',
      minPlayers: rules.minPlayers,
      maxPlayers: rules.maxPlayers,
      category: GameCategory.cardGame,
    ),
  );
}
