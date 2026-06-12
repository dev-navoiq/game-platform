import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';

/// Coordinates "ready for next round" signals between players using a
/// per-round Supabase broadcast channel.
///
/// This is intentionally UI-only — the engine does not see these signals.
/// Bots are auto-marked ready on subscribe; humans broadcast on tap.
class ReadyBroadcastController extends StateNotifier<Set<String>> {
  ReadyBroadcastController(this._supabase) : super(const {});

  final SupabaseClient _supabase;

  RealtimeChannel? _channel;
  String? _channelName;

  static const _eventName = 'ready';

  Future<void> subscribe({
    required String roomId,
    required int roundNumber,
    required List<String> botPlayerIds,
  }) async {
    final name = 'room:$roomId:ready:$roundNumber';
    if (_channelName == name && _channel != null) {
      state = {...state, ...botPlayerIds};
      return;
    }

    await _teardown();

    final channel = _supabase.channel(name);
    channel.onBroadcast(
      event: _eventName,
      callback: (payload) {
        final id = payload['playerId'];
        if (id is String && id.isNotEmpty) {
          if (!mounted) return;
          if (state.contains(id)) return;
          state = {...state, id};
        }
      },
    ).subscribe();

    _channel = channel;
    _channelName = name;
    state = {...botPlayerIds};
  }

  Future<void> markReady(String playerId) async {
    if (!state.contains(playerId)) {
      state = {...state, playerId};
    }
    final channel = _channel;
    if (channel == null) return;
    await channel.sendBroadcastMessage(
      event: _eventName,
      payload: {
        'playerId': playerId,
        'ts': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> reset() async {
    await _teardown();
    if (mounted) state = const {};
  }

  Future<void> _teardown() async {
    final channel = _channel;
    _channel = null;
    _channelName = null;
    if (channel == null) return;
    try {
      await _supabase.removeChannel(channel);
    } catch (_) {
      // Already removed or never fully subscribed — ignore.
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    _channelName = null;
    if (channel != null) {
      try {
        _supabase.removeChannel(channel);
      } catch (_) {
        // Ignore teardown errors during dispose.
      }
    }
    super.dispose();
  }
}

final readyBroadcastControllerProvider =
    StateNotifierProvider.autoDispose<ReadyBroadcastController, Set<String>>(
        (ref) {
  final supabase = ref.read(supabaseProvider);
  return ReadyBroadcastController(supabase);
});
