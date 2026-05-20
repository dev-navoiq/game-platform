import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets/asset_registry.dart';
import '../assets/card_skin_theme.dart';
import '../assets/room_skin_theme.dart';
import 'providers.dart';

/// Resolves the user's selected card skin ID to a [CardSkinTheme].
final cardSkinThemeProvider = Provider<CardSkinTheme>((ref) {
  final skinId = ref.watch(selectedCardSkinProvider);
  return AssetRegistry.instance.getCardSkin(skinId);
});

/// Resolves the user's selected room skin ID to a [RoomSkinTheme].
final roomSkinThemeProvider = Provider<RoomSkinTheme>((ref) {
  final skinId = ref.watch(selectedRoomSkinProvider);
  return AssetRegistry.instance.getRoomSkin(skinId);
});
