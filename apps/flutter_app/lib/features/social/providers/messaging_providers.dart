import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_core/social_core.dart';

import '../../../core/di/providers.dart';
import '../data/supabase_direct_message_repository.dart';
import '../data/supabase_presence_repository.dart';

// ── Repository providers ──

final directMessageRepositoryProvider =
    Provider<DirectMessageRepository>((ref) {
  return SupabaseDirectMessageRepository(ref.watch(supabaseProvider));
});

/// The presence repo is a long-lived singleton — it owns a Realtime channel
/// and we don't want it torn down/recreated as widgets rebuild. The Provider
/// wires `ref.onDispose` so a full ProviderScope swap (e.g. in tests) cleans
/// up the channel.
final presenceRepositoryProvider = Provider<SupabasePresenceRepository>((ref) {
  final repo = SupabasePresenceRepository(ref.watch(supabaseProvider));
  ref.onDispose(() {
    repo.stop();
  });
  return repo;
});

/// Side-effecting provider: starts/stops the presence channel as the auth
/// state changes. Read it once from the app shell (`ref.watch(...)`) so it
/// stays alive for the whole session.
final presenceBootstrapProvider = Provider<void>((ref) {
  final repo = ref.watch(presenceRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (user != null) {
    final displayName =
        (user.userMetadata?['display_name'] as String?) ??
            (user.userMetadata?['username'] as String?) ??
            user.email;
    // Fire-and-forget; the repo handles errors and is idempotent.
    repo.start(userId: user.id, displayName: displayName);
  } else {
    repo.stop();
  }
});

// ── Stream providers ──

/// Inbox = one row per other-user with last message + unread count.
final dmInboxProvider =
    StreamProvider<List<DirectMessageThread>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value(const []);
  return ref
      .watch(directMessageRepositoryProvider)
      .watchInbox(currentUserId: userId);
});

/// All messages in a specific 1:1 thread, oldest-first. Keyed by the
/// OTHER user's id.
final dmThreadProvider =
    StreamProvider.family<List<DirectMessage>, String>((ref, otherUserId) {
  final selfId = ref.watch(currentUserProvider)?.id;
  if (selfId == null) return Stream.value(const []);
  return ref.watch(directMessageRepositoryProvider).watchThread(
        userAId: selfId,
        userBId: otherUserId,
      );
});

/// Online users from the presence channel (excludes self).
final onlineUsersProvider = StreamProvider<List<OnlineUser>>((ref) {
  // Make sure the channel is up before subscribers start reading.
  ref.watch(presenceBootstrapProvider);
  return ref.watch(presenceRepositoryProvider).watchOnline();
});

/// Cheap derived set of online user IDs for `.contains()` lookups in lists.
final onlineUserIdsProvider = Provider<Set<String>>((ref) {
  final users = ref.watch(onlineUsersProvider).valueOrNull ?? const [];
  return users.map((u) => u.userId).toSet();
});

// ── Profile resolver ──

/// One-shot profile fetch used by the DM thread screen to render the
/// other user's name + avatar in the header. autoDispose so we don't
/// keep stale Auth-scoped data after navigation.
final dmPeerProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, otherUserId) async {
  final client = ref.read(supabaseProvider);
  try {
    final row = await client
        .from('profiles')
        .select('id, display_name, username, avatar_url')
        .eq('id', otherUserId)
        .maybeSingle();
    return row;
  } catch (_) {
    return null;
  }
});
