import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import 'social_providers.dart';

/// Blocked user IDs for the current user.
final blockedUserIdsProvider = FutureProvider<List<String>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  return ref.watch(friendsRepositoryProvider).getBlockedUserIds(userId: userId);
});

/// Whether a specific user is blocked.
final isUserBlockedProvider =
    Provider.family<bool, String>((ref, targetUserId) {
  final blocked = ref.watch(blockedUserIdsProvider).valueOrNull ?? [];
  return blocked.contains(targetUserId);
});
