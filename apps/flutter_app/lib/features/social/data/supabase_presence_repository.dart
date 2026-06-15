import 'dart:async';

import 'package:social_core/social_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Realtime presence implementation. One shared channel,
/// "global_lobby", carries every signed-in user's presence so the
/// inbox/friend-list can render an accurate green dot without polling
/// `profiles.current_activity`.
///
/// Track payload shape (kept narrow so updates are cheap):
///   {
///     "user_id": "<uuid>",
///     "display_name": "<string>",
///     "activity": "in_game" | "in_lobby" | null,
///     "room_id": "<uuid>" | null,
///   }
///
/// We don't persist anything to Postgres — presence is ephemeral by design.
class SupabasePresenceRepository implements PresenceRepository {
  static const _channelName = 'global_lobby';

  final SupabaseClient _client;

  RealtimeChannel? _channel;
  String? _userId;
  String? _displayName;
  String? _activity;
  String? _roomId;

  final _onlineController =
      StreamController<List<OnlineUser>>.broadcast();
  List<OnlineUser> _latest = const [];

  SupabasePresenceRepository(this._client);

  @override
  Future<void> start({
    required String userId,
    String? displayName,
    String? activity,
    String? roomId,
  }) async {
    if (_channel != null) return; // idempotent

    _userId = userId;
    _displayName = displayName;
    _activity = activity;
    _roomId = roomId;

    _channel = _client.channel(
      _channelName,
      opts: const RealtimeChannelConfig(self: false),
    );

    _channel!
        .onPresenceSync((_) => _emitFromState())
        .onPresenceJoin((_) => _emitFromState())
        .onPresenceLeave((_) => _emitFromState())
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _channel!.track(_trackPayload());
          }
        });
  }

  @override
  Future<void> stop() async {
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {/* channel may already be closed */}
      await _client.removeChannel(ch);
    }
    _latest = const [];
    _emit(_latest);
  }

  @override
  Future<void> updateActivity({String? activity, String? roomId}) async {
    _activity = activity;
    _roomId = roomId;
    final ch = _channel;
    if (ch == null) return;
    try {
      await ch.track(_trackPayload());
    } catch (_) {/* swallow — next sync will catch up */}
  }

  @override
  Stream<List<OnlineUser>> watchOnline() => _onlineController.stream;

  @override
  bool isOnline(String userId) =>
      _latest.any((u) => u.userId == userId);

  // ──────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _trackPayload() => {
        'user_id': _userId,
        if (_displayName != null) 'display_name': _displayName,
        if (_activity != null) 'activity': _activity,
        if (_roomId != null) 'room_id': _roomId,
      };

  void _emitFromState() {
    final state = _channel?.presenceState() ?? const [];
    final users = <String, OnlineUser>{};

    for (final presence in state) {
      for (final p in presence.presences) {
        final payload = p.payload;
        final id = payload['user_id'] as String?;
        if (id == null || id == _userId) continue;
        users[id] = OnlineUser(
          userId: id,
          displayName: payload['display_name'] as String?,
          activity: payload['activity'] as String?,
          roomId: payload['room_id'] as String?,
        );
      }
    }

    _emit(users.values.toList());
  }

  void _emit(List<OnlineUser> users) {
    _latest = users;
    if (!_onlineController.isClosed) _onlineController.add(users);
  }
}
