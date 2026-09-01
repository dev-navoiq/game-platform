import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/shop_repository.dart';
import '../../../core/di/providers.dart';

/// Repository provider for shop operations
final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(ref.watch(supabaseProvider));
});

/// Owned skin IDs provider - invalidate after purchase to refresh
final ownedSkinsProvider = FutureProvider<Set<String>>((ref) async {
  final repository = ref.watch(shopRepositoryProvider);
  final ownedList = await repository.getOwnedSkins();
  return ownedList.toSet();
});
