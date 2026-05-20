import 'package:game_core/game_core.dart';

/// Minimal stub for Bridge — full implementation planned for a future session.
///
/// Bridge is a 4-player, 2v2 trick-taking game with complex bidding (auction),
/// contract declaration, and advanced card-play rules. Its complexity warrants
/// a dedicated implementation session.
class BridgeGameDescriptor {
  static GameDescriptor descriptor() => const GameDescriptor(
        id: 'bridge',
        name: 'Bridge',
        minPlayers: 4,
        maxPlayers: 4,
        category: GameCategory.cardGame,
      );
}

/// Register Bridge with the provided [registry] (stub — no rules yet).
void registerBridge(GameRegistry registry) {
  registry.register(BridgeGameDescriptor.descriptor());
}
