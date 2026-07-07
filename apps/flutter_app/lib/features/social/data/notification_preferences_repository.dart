import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mirrors one row of `notification_preferences` (auto-created per user by
/// the handle_new_user trigger, so a fetch should always find one; defaults
/// cover the pathological case where it doesn't).
class NotificationPreferences {
  final bool gameInvites;
  final bool friendActivity;
  final bool turnReminders;
  final bool chatMessages;
  final bool tournamentUpdates;
  final bool challengeReminders;
  final bool seasonEvents;
  final bool dailyBonus;
  final bool promotional;
  final bool systemUpdates;
  final bool quietHoursEnabled;
  final TimeOfDay quietHoursStart;
  final TimeOfDay quietHoursEnd;

  const NotificationPreferences({
    this.gameInvites = true,
    this.friendActivity = true,
    this.turnReminders = true,
    this.chatMessages = true,
    this.tournamentUpdates = true,
    this.challengeReminders = true,
    this.seasonEvents = true,
    this.dailyBonus = true,
    this.promotional = false,
    this.systemUpdates = true,
    this.quietHoursEnabled = true,
    this.quietHoursStart = const TimeOfDay(hour: 22, minute: 0),
    this.quietHoursEnd = const TimeOfDay(hour: 8, minute: 0),
  });

  static TimeOfDay _time(String? raw, TimeOfDay fallback) {
    if (raw == null) return fallback;
    final parts = raw.split(':');
    final h = int.tryParse(parts[0]);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    const defaults = NotificationPreferences();
    return NotificationPreferences(
      gameInvites: json['game_invites'] as bool? ?? defaults.gameInvites,
      friendActivity:
          json['friend_activity'] as bool? ?? defaults.friendActivity,
      turnReminders: json['turn_reminders'] as bool? ?? defaults.turnReminders,
      chatMessages: json['chat_messages'] as bool? ?? defaults.chatMessages,
      tournamentUpdates:
          json['tournament_updates'] as bool? ?? defaults.tournamentUpdates,
      challengeReminders:
          json['challenge_reminders'] as bool? ?? defaults.challengeReminders,
      seasonEvents: json['season_events'] as bool? ?? defaults.seasonEvents,
      dailyBonus: json['daily_bonus'] as bool? ?? defaults.dailyBonus,
      promotional: json['promotional'] as bool? ?? defaults.promotional,
      systemUpdates: json['system_updates'] as bool? ?? defaults.systemUpdates,
      quietHoursEnabled:
          json['quiet_hours_enabled'] as bool? ?? defaults.quietHoursEnabled,
      quietHoursStart: _time(
          json['quiet_hours_start'] as String?, defaults.quietHoursStart),
      quietHoursEnd:
          _time(json['quiet_hours_end'] as String?, defaults.quietHoursEnd),
    );
  }
}

class NotificationPreferencesRepository {
  final SupabaseClient _client;

  NotificationPreferencesRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<NotificationPreferences> fetch() async {
    final row = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null
        ? const NotificationPreferences()
        : NotificationPreferences.fromJson(row);
  }

  /// Persist a single toggle; [column] must be a notification_preferences
  /// column name.
  Future<void> setFlag(String column, bool value) async {
    await _client.from('notification_preferences').update({
      column: value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', _userId);
  }

  Future<void> setQuietHours({
    required bool enabled,
    required TimeOfDay start,
    required TimeOfDay end,
  }) async {
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await _client.from('notification_preferences').update({
      'quiet_hours_enabled': enabled,
      'quiet_hours_start': fmt(start),
      'quiet_hours_end': fmt(end),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', _userId);
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
  return NotificationPreferencesRepository(Supabase.instance.client);
});

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) {
  return ref.watch(notificationPreferencesRepositoryProvider).fetch();
});
