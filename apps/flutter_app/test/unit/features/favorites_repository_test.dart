import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/favorites/providers/favorites_providers.dart';

void main() {
  group('FavoritesNotifier', () {
    test('initial state is empty list', () {
      final notifier = FavoritesNotifier(null);
      expect(notifier.debugState, isEmpty);
    });

    test('toggle adds then removes (no repo, optimistic only)', () async {
      final notifier = FavoritesNotifier(null);

      // Toggle on — no repo so no server call, but state updates
      await notifier.toggle('chess');
      expect(notifier.debugState, contains('chess'));

      // Toggle off
      await notifier.toggle('chess');
      expect(notifier.debugState, isNot(contains('chess')));
    });

    test('add is idempotent', () async {
      final notifier = FavoritesNotifier(null);

      await notifier.add('ludo');
      await notifier.add('ludo');
      expect(
        notifier.debugState.where((g) => g == 'ludo').length,
        1,
      );
    });

    test('remove from empty list is safe', () async {
      final notifier = FavoritesNotifier(null);
      await notifier.remove('nonexistent');
      expect(notifier.debugState, isEmpty);
    });

    test('multiple games maintained in order', () async {
      final notifier = FavoritesNotifier(null);

      await notifier.add('chess');
      await notifier.add('ludo');
      await notifier.add('hearts');

      expect(notifier.debugState, ['chess', 'ludo', 'hearts']);
    });
  });
}
