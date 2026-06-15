import 'package:equatable/equatable.dart';

/// A user the presence channel knows is online right now.
class OnlineUser extends Equatable {
  final String userId;
  final String? displayName;

  /// Optional snapshot of `profiles.current_activity.type`
  /// (`in_game` | `in_lobby` | null). Lets the UI show whether an online
  /// friend is mid-game without an extra round-trip.
  final String? activity;

  /// Optional `current_activity.room_id` so an invite button can short-
  /// circuit to "join their room" instead of starting a new one.
  final String? roomId;

  const OnlineUser({
    required this.userId,
    this.displayName,
    this.activity,
    this.roomId,
  });

  @override
  List<Object?> get props => [userId, displayName, activity, roomId];
}

/// Live online-presence channel. Implementations should use Supabase
/// Realtime's presence primitive (one shared channel per app) rather
/// than polling `profiles.current_activity`.
///
/// The lifecycle is: call [start] once the user is signed in (typically
/// from the app shell), call [stop] on sign-out, and consume [watchOnline]
/// from any screen that needs to render online state.
abstract class PresenceRepository {
  /// Begin broadcasting that the current user is online and start
  /// listening to other users. Idempotent: calling twice is a no-op.
  Future<void> start({
    required String userId,
    String? displayName,
    String? activity,
    String? roomId,
  });

  /// Stop broadcasting and tear down the channel.
  Future<void> stop();

  /// Update the broadcast payload (e.g. when the user enters a room).
  /// No-op if [start] hasn't been called.
  Future<void> updateActivity({String? activity, String? roomId});

  /// Snapshot of who's online right now (excluding the current user).
  Stream<List<OnlineUser>> watchOnline();

  /// True iff [userId] is currently in the presence set.
  bool isOnline(String userId);
}
