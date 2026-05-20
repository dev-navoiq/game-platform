/// Abstract game framework — interfaces, state machines, type-safe generics.
library game_core;

// ── Cards ───────────────────────────────────────────────────────────────────
export 'src/cards/playing_card.dart'; // PlayingCard, Suit, Rank
export 'src/cards/deck.dart'; // Deck
export 'src/cards/hand.dart'; // Hand
export 'src/cards/trick_card.dart'; // TrickCard

// ── Board ───────────────────────────────────────────────────────────────────
export 'src/board/board_position.dart'; // BoardPosition
export 'src/board/board_piece.dart'; // BoardPiece, PieceType
export 'src/board/board_state.dart'; // BoardState (abstract)
export 'src/board/board_rules.dart'; // BoardRules (abstract)

// ── Rules / State Machine ───────────────────────────────────────────────────
export 'src/rules/room_social_mode.dart'; // RoomSocialMode
export 'src/rules/game_phase.dart'; // GamePhase
export 'src/rules/game_state.dart'; // GameState (abstract)
export 'src/rules/game_move.dart'; // GameMove (abstract), MoveType
export 'src/rules/game_rules.dart'; // GameRules (abstract), MoveResult
export 'src/rules/game_event.dart'; // GameEvent, GameEventType

// ── Registry ─────────────────────────────────────────────────────────────────
export 'src/registry/game_category.dart'; // GameCategory
export 'src/registry/game_descriptor.dart'; // GameDescriptor
export 'src/registry/game_registry.dart'; // GameRegistry
