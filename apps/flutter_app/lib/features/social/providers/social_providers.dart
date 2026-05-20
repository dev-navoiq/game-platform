import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_core/social_core.dart';

import '../../../core/di/providers.dart';
import '../data/supabase_chat_repository.dart';
import '../data/supabase_friends_repository.dart';
import '../data/supabase_moderation_repository.dart';
import '../data/supabase_reaction_repository.dart';

// ── Repository providers ──

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(ref.watch(supabaseProvider));
});

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return SupabaseFriendsRepository(ref.watch(supabaseProvider));
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return SupabaseModerationRepository(ref.watch(supabaseProvider));
});

final reactionRepositoryProvider = Provider<ReactionRepository>((ref) {
  return SupabaseReactionRepository(ref.watch(supabaseProvider));
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return StubVoiceService();
});

// ── Stream providers (family by roomId) ──

final roomChatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).watchMessages(roomId: roomId);
});

final roomPlayerChatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
  return ref
      .watch(chatRepositoryProvider)
      .watchMessages(roomId: roomId, isSpectatorChat: false);
});

final roomSpectatorChatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
  return ref
      .watch(chatRepositoryProvider)
      .watchMessages(roomId: roomId, isSpectatorChat: true);
});

final roomReactionsProvider =
    StreamProvider.family<List<Reaction>, String>((ref, roomId) {
  return ref.watch(reactionRepositoryProvider).watchReactions(roomId: roomId);
});

final roomMuteVotesProvider =
    StreamProvider.family<List<MuteVote>, String>((ref, roomId) {
  return ref
      .watch(moderationRepositoryProvider)
      .watchMuteVotes(roomId: roomId);
});

// ── Derived providers for floating bubbles ──

/// Latest chat message per player (for floating bubbles on PlayerNodes).
/// Only includes messages from the last 5 seconds.
final latestChatByPlayerProvider =
    Provider.family<Map<String, ChatMessage>, String>((ref, roomId) {
  final messages =
      ref.watch(roomPlayerChatMessagesProvider(roomId)).valueOrNull ?? [];
  final cutoff = DateTime.now().subtract(const Duration(seconds: 5));

  final result = <String, ChatMessage>{};
  for (final msg in messages.reversed) {
    if (msg.createdAt.isBefore(cutoff)) break;
    result.putIfAbsent(msg.userId, () => msg);
  }
  return result;
});

/// Latest reaction per player (for floating emoji bubbles on PlayerNodes).
/// Only includes reactions from the last 5 seconds.
final latestReactionByPlayerProvider =
    Provider.family<Map<String, Reaction>, String>((ref, roomId) {
  final reactions =
      ref.watch(roomReactionsProvider(roomId)).valueOrNull ?? [];
  final cutoff = DateTime.now().subtract(const Duration(seconds: 5));

  final result = <String, Reaction>{};
  for (final reaction in reactions.reversed) {
    if (reaction.createdAt.isBefore(cutoff)) break;
    result.putIfAbsent(reaction.userId, () => reaction);
  }
  return result;
});
