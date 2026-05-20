import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/assets/asset_registry.dart';
import 'package:flutter_app/core/assets/card_skin_theme.dart';
import 'package:flutter_app/core/assets/room_skin_theme.dart';

void main() {
  group('AssetRegistry', () {
    late AssetRegistry registry;

    setUp(() {
      registry = AssetRegistry.instance;
    });

    group('Card skins', () {
      test('allCardSkins returns 4 presets', () {
        expect(registry.allCardSkins, hasLength(4));
      });

      test('getCardSkin resolves known IDs', () {
        expect(registry.getCardSkin('classic').id, 'classic');
        expect(registry.getCardSkin('modern').id, 'modern');
        expect(registry.getCardSkin('neon').id, 'neon');
        expect(registry.getCardSkin('gold').id, 'gold');
      });

      test('"default" maps to classic', () {
        final skin = registry.getCardSkin('default');
        expect(skin.id, 'classic');
        expect(skin.isDefault, isTrue);
      });

      test('unknown ID falls back to classic', () {
        final skin = registry.getCardSkin('nonexistent_skin');
        expect(skin.id, 'classic');
      });

      test('all presets have valid colour properties', () {
        for (final skin in registry.allCardSkins) {
          expect(skin.id, isNotEmpty);
          expect(skin.displayName, isNotEmpty);
          expect(skin.redSuitColor, isNotNull);
          expect(skin.blackSuitColor, isNotNull);
          expect(skin.cardFaceColor, isNotNull);
          expect(skin.cardBorderColor, isNotNull);
          expect(skin.cardBackGradient.colors, hasLength(2));
        }
      });

      test('only classic is default', () {
        final defaults =
            registry.allCardSkins.where((s) => s.isDefault).toList();
        expect(defaults, hasLength(1));
        expect(defaults.first.id, 'classic');
      });

      test('classic is free', () {
        expect(CardSkinTheme.classic.isFree, isTrue);
      });

      test('non-classic skins have a price', () {
        expect(CardSkinTheme.modern.isFree, isFalse);
        expect(CardSkinTheme.neon.isFree, isFalse);
        expect(CardSkinTheme.gold.isFree, isFalse);
      });
    });

    group('Room skins', () {
      test('allRoomSkins returns 4 presets', () {
        expect(registry.allRoomSkins, hasLength(4));
      });

      test('getRoomSkin resolves known IDs', () {
        expect(registry.getRoomSkin('classic').id, 'classic');
        expect(registry.getRoomSkin('casino').id, 'casino');
        expect(registry.getRoomSkin('nature').id, 'nature');
        expect(registry.getRoomSkin('space').id, 'space');
      });

      test('"default" maps to classic', () {
        final skin = registry.getRoomSkin('default');
        expect(skin.id, 'classic');
        expect(skin.isDefault, isTrue);
      });

      test('unknown ID falls back to classic', () {
        final skin = registry.getRoomSkin('unknown_room');
        expect(skin.id, 'classic');
      });

      test('all presets have valid gradient colours', () {
        for (final skin in registry.allRoomSkins) {
          expect(skin.id, isNotEmpty);
          expect(skin.displayName, isNotEmpty);
          expect(skin.feltColor, isNotNull);
          expect(skin.feltDarkColor, isNotNull);
          expect(skin.accentColor, isNotNull);
          expect(skin.glassOpacity, greaterThan(0));
          expect(skin.glassOpacity, lessThanOrEqualTo(1));
        }
      });

      test('only classic is default', () {
        final defaults =
            registry.allRoomSkins.where((s) => s.isDefault).toList();
        expect(defaults, hasLength(1));
        expect(defaults.first.id, 'classic');
      });

      test('classic is free', () {
        expect(RoomSkinTheme.classic.isFree, isTrue);
      });

      test('non-classic skins have a price', () {
        expect(RoomSkinTheme.casino.isFree, isFalse);
        expect(RoomSkinTheme.nature.isFree, isFalse);
        expect(RoomSkinTheme.space.isFree, isFalse);
      });
    });
  });
}
