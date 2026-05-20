import 'card_skin_theme.dart';
import 'room_skin_theme.dart';

/// Central registry mapping skin IDs to their theme definitions.
///
/// All themes are code-defined (no image assets), so lookup is synchronous.
class AssetRegistry {
  AssetRegistry._();

  static final AssetRegistry instance = AssetRegistry._();

  // ── Card skins ──────────────────────────────────────────────────────────

  static const _cardSkins = <String, CardSkinTheme>{
    'classic': CardSkinTheme.classic,
    'default': CardSkinTheme.classic,
    'modern': CardSkinTheme.modern,
    'neon': CardSkinTheme.neon,
    'gold': CardSkinTheme.gold,
  };

  /// All unique card skin themes (excludes the 'default' alias).
  List<CardSkinTheme> get allCardSkins => const [
        CardSkinTheme.classic,
        CardSkinTheme.modern,
        CardSkinTheme.neon,
        CardSkinTheme.gold,
      ];

  /// Returns the [CardSkinTheme] for the given [id].
  /// Falls back to [CardSkinTheme.classic] for unknown IDs.
  CardSkinTheme getCardSkin(String id) {
    return _cardSkins[id] ?? CardSkinTheme.classic;
  }

  // ── Room skins ──────────────────────────────────────────────────────────

  static const _roomSkins = <String, RoomSkinTheme>{
    'classic': RoomSkinTheme.classic,
    'default': RoomSkinTheme.classic,
    'casino': RoomSkinTheme.casino,
    'nature': RoomSkinTheme.nature,
    'space': RoomSkinTheme.space,
  };

  /// All unique room skin themes (excludes the 'default' alias).
  List<RoomSkinTheme> get allRoomSkins => const [
        RoomSkinTheme.classic,
        RoomSkinTheme.casino,
        RoomSkinTheme.nature,
        RoomSkinTheme.space,
      ];

  /// Returns the [RoomSkinTheme] for the given [id].
  /// Falls back to [RoomSkinTheme.classic] for unknown IDs.
  RoomSkinTheme getRoomSkin(String id) {
    return _roomSkins[id] ?? RoomSkinTheme.classic;
  }
}
