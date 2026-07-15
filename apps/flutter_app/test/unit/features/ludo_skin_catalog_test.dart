import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/game/presentation/ludo/ludo_skin_catalog.dart';
import 'package:flutter_app/features/game/presentation/ludo/ludo_sponsor_branding.dart';

void main() {
  group('kLudoSkins', () {
    test('ids are unique', () {
      final ids = kLudoSkins.map((s) => s.id).toSet();
      expect(ids.length, kLudoSkins.length);
    });

    test('first entry is the free, unsponsored default', () {
      expect(kLudoSkins.first.premium, isFalse);
      expect(kLudoSkins.first.sponsor, isNull);
    });

    test('ludoSkinById falls back to the default for unknown ids', () {
      expect(ludoSkinById('does-not-exist').id, kLudoSkins.first.id);
      expect(ludoSkinById('rider-bike').id, 'rider-bike');
    });
  });

  group('sponsored skins', () {
    final sponsored =
        kLudoSkins.where((s) => s.sponsor != null).toList();

    test('both example sponsors are in the catalog', () {
      expect(
        sponsored.map((s) => s.sponsor!.sponsorName),
        containsAll(['Bolt Cola', 'Nimbus Airways']),
      );
    });

    test('sponsored skins are free to equip (sponsor pays, not the player)',
        () {
      for (final s in sponsored) {
        expect(s.premium, isFalse, reason: '${s.id} should not be premium');
      }
    });

    test('sponsored skins wrap a base skin with matching branding', () {
      for (final s in sponsored) {
        expect(s.skin, isA<SponsoredRiderSkin>(),
            reason: '${s.id} should use the SponsoredRiderSkin wrapper');
        final wrapper = s.skin as SponsoredRiderSkin;
        expect(wrapper.branding, same(s.sponsor),
            reason: '${s.id}: token livery and board accent must agree');
      }
    });

    test('badge text is short enough for the board roundel', () {
      for (final s in sponsored) {
        expect(s.sponsor!.badgeText.length, lessThanOrEqualTo(8),
            reason: '${s.id}: badgeText must fit a board cell');
      }
    });
  });
}
