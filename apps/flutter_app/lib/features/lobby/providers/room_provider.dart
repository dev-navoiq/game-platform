import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';

final roomProvider =
    AsyncNotifierProvider<RoomNotifier, void>(RoomNotifier.new);

class RoomNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Initial loading state
  }

  SupabaseService get _supabase => ref.read(supabaseServiceProvider);

  Future<String> createRoom({
    required String gameType,
    required String socialMode,
  }) async {
    final result = await _supabase.createRoom(
      gameType: gameType,
      socialMode: socialMode,
    );
    return result['room_id'] as String;
  }

  Future<void> leaveRoom({required String roomId}) async {
    await _supabase.leaveRoom(roomId: roomId);
  }
}
