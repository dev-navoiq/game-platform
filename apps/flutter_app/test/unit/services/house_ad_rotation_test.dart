import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/house_ads/house_ad_catalog.dart';
import 'package:flutter_app/core/services/house_ads/house_ad_creative.dart';
import 'package:flutter_app/core/services/house_ads/house_ad_rotation.dart';

HouseAdCreative _creative(String id) => HouseAdCreative(
      id: id,
      headline: id,
      body: 'body of $id',
      ctaLabel: 'Go',
      accentColor: const Color(0xFFC47B2B),
    );

void main() {
  group('HouseAdRotation', () {
    final catalog = [_creative('a'), _creative('b'), _creative('c')];

    test('serves creatives round-robin in catalog order, wrapping', () async {
      final rotation =
          HouseAdRotation(InMemoryHouseAdRotationStore(), catalog: catalog);

      final served = [
        for (var i = 0; i < 7; i++) (await rotation.next()).id,
      ];

      expect(served, ['a', 'b', 'c', 'a', 'b', 'c', 'a']);
    });

    test('persists the cursor: a new rotation over the same store continues '
        'where the last one stopped', () async {
      final store = InMemoryHouseAdRotationStore();

      final first = HouseAdRotation(store, catalog: catalog);
      expect((await first.next()).id, 'a');
      expect((await first.next()).id, 'b');

      // Simulate an app restart: fresh rotation, same store.
      final second = HouseAdRotation(store, catalog: catalog);
      expect((await second.next()).id, 'c');
      expect((await second.next()).id, 'a');
    });

    test('tolerates a stored index beyond the catalog length '
        '(e.g. catalog shrank between releases)', () async {
      final store = InMemoryHouseAdRotationStore();
      await store.setNextIndex(302);

      final rotation = HouseAdRotation(store, catalog: catalog);
      expect((await rotation.next()).id, catalog[302 % 3].id);
      expect((await rotation.next()).id, catalog[303 % 3].id);
    });

    test('defaults to the built-in catalog', () async {
      final rotation = HouseAdRotation(InMemoryHouseAdRotationStore());
      expect(rotation.catalog, kHouseAdCatalog);
      expect((await rotation.next()).id, kHouseAdCatalog.first.id);
    });
  });

  group('kHouseAdCatalog', () {
    test('has 4-5 creatives with unique ids', () {
      expect(kHouseAdCatalog.length, inInclusiveRange(4, 5));
      final ids = kHouseAdCatalog.map((c) => c.id).toSet();
      expect(ids.length, kHouseAdCatalog.length);
    });

    test('sponsor demo creative is clearly marked and has no destination',
        () {
      final sponsor =
          kHouseAdCatalog.singleWhere((c) => c.id == 'bolt_cola_demo');
      expect(sponsor.adLabel, 'Sponsored · Demo');
      expect(sponsor.route, isNull);
    });

    test('own creatives carry the Gathr ad label and a route', () {
      for (final c in kHouseAdCatalog.where((c) => c.id != 'bolt_cola_demo')) {
        expect(c.adLabel, 'Ad · Gathr', reason: c.id);
        expect(c.route, isNotNull, reason: c.id);
      }
    });
  });
}
