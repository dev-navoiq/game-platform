import 'package:game_core/game_core.dart';

import 'bridge_rules.dart';

/// Registers Bridge with the provided [GameRegistry].
void registerBridge(GameRegistry registry) {
  final rules = BridgeRules();
  registry.register(
    GameDescriptor(
      id: 'bridge',
      name: 'Bridge',
      minPlayers: rules.minPlayers,
      maxPlayers: rules.maxPlayers,
      category: GameCategory.cardGame,
    ),
  );
}
