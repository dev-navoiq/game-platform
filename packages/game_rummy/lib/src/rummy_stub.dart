import 'package:game_core/game_core.dart';

/// Minimal stub for Rummy — full implementation planned for a future session.
///
/// Rummy is a group of matching-card games notable for same-rank or
/// sequence gameplay. The variant to be implemented is Gin Rummy or Indian
/// Rummy (13 cards, 2–6 players). Its rules and meld validation logic warrant
/// a dedicated implementation session.
class RummyGameDescriptor {
  static GameDescriptor descriptor() => const GameDescriptor(
        id: 'rummy',
        name: 'Rummy',
        minPlayers: 2,
        maxPlayers: 6,
        category: GameCategory.cardGame,
      );
}

/// Register Rummy with the provided [registry] (stub — no rules yet).
void registerRummy(GameRegistry registry) {
  registry.register(RummyGameDescriptor.descriptor());
}
