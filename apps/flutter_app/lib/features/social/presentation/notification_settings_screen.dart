import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/notification_preferences_repository.dart';

/// Notification preferences, persisted per-toggle to the
/// `notification_preferences` table (which the notify-dispatch edge function
/// honours server-side before sending any push).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // Local working copy so toggles respond instantly; each change is written
  // through immediately and rolled back on failure.
  NotificationPreferences? _prefs;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs =
          await ref.read(notificationPreferencesRepositoryProvider).fetch();
      if (mounted) setState(() => _prefs = prefs);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _setFlag(String column, bool value) async {
    final before = _prefs;
    setState(() => _prefs = _copyWithFlag(_prefs!, column, value));
    try {
      await ref
          .read(notificationPreferencesRepositoryProvider)
          .setFlag(column, value);
    } catch (_) {
      if (mounted) {
        setState(() => _prefs = before);
        _showSaveError();
      }
    }
  }

  Future<void> _saveQuietHours({
    bool? enabled,
    TimeOfDay? start,
    TimeOfDay? end,
  }) async {
    final before = _prefs!;
    final next = NotificationPreferences(
      gameInvites: before.gameInvites,
      friendActivity: before.friendActivity,
      turnReminders: before.turnReminders,
      chatMessages: before.chatMessages,
      tournamentUpdates: before.tournamentUpdates,
      challengeReminders: before.challengeReminders,
      seasonEvents: before.seasonEvents,
      dailyBonus: before.dailyBonus,
      promotional: before.promotional,
      systemUpdates: before.systemUpdates,
      quietHoursEnabled: enabled ?? before.quietHoursEnabled,
      quietHoursStart: start ?? before.quietHoursStart,
      quietHoursEnd: end ?? before.quietHoursEnd,
    );
    setState(() => _prefs = next);
    try {
      await ref.read(notificationPreferencesRepositoryProvider).setQuietHours(
            enabled: next.quietHoursEnabled,
            start: next.quietHoursStart,
            end: next.quietHoursEnd,
          );
    } catch (_) {
      if (mounted) {
        setState(() => _prefs = before);
        _showSaveError();
      }
    }
  }

  NotificationPreferences _copyWithFlag(
    NotificationPreferences p,
    String column,
    bool value,
  ) {
    return NotificationPreferences(
      gameInvites: column == 'game_invites' ? value : p.gameInvites,
      friendActivity: column == 'friend_activity' ? value : p.friendActivity,
      turnReminders: column == 'turn_reminders' ? value : p.turnReminders,
      chatMessages: column == 'chat_messages' ? value : p.chatMessages,
      tournamentUpdates:
          column == 'tournament_updates' ? value : p.tournamentUpdates,
      challengeReminders:
          column == 'challenge_reminders' ? value : p.challengeReminders,
      seasonEvents: column == 'season_events' ? value : p.seasonEvents,
      dailyBonus: column == 'daily_bonus' ? value : p.dailyBonus,
      promotional: column == 'promotional' ? value : p.promotional,
      systemUpdates: column == 'system_updates' ? value : p.systemUpdates,
      quietHoursEnabled: p.quietHoursEnabled,
      quietHoursStart: p.quietHoursStart,
      quietHoursEnd: p.quietHoursEnd,
    );
  }

  void _showSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't save — check your connection")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: _loadFailed
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Couldn't load your preferences",
                    style: GoogleFonts.inter(color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() => _loadFailed = false);
                      _load();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : prefs == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSection('Game Notifications', [
                      _buildToggle('Game Invites', prefs.gameInvites,
                          (v) => _setFlag('game_invites', v)),
                      _buildToggle(
                          'Friend Requests & Activity',
                          prefs.friendActivity,
                          (v) => _setFlag('friend_activity', v)),
                      _buildToggle('Turn Reminders', prefs.turnReminders,
                          (v) => _setFlag('turn_reminders', v)),
                      _buildToggle('Chat Messages', prefs.chatMessages,
                          (v) => _setFlag('chat_messages', v)),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Progress & Rewards', [
                      _buildToggle(
                          'Tournament Updates',
                          prefs.tournamentUpdates,
                          (v) => _setFlag('tournament_updates', v)),
                      _buildToggle(
                          'Challenge Reminders',
                          prefs.challengeReminders,
                          (v) => _setFlag('challenge_reminders', v)),
                      _buildToggle('Season Events', prefs.seasonEvents,
                          (v) => _setFlag('season_events', v)),
                      _buildToggle('Daily Bonus', prefs.dailyBonus,
                          (v) => _setFlag('daily_bonus', v)),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Other', [
                      _buildToggle('Promotions & Offers', prefs.promotional,
                          (v) => _setFlag('promotional', v)),
                      _buildToggle('System Updates', prefs.systemUpdates,
                          (v) => _setFlag('system_updates', v)),
                    ]),
                    const SizedBox(height: 16),
                    _buildQuietHoursSection(prefs),
                  ],
                ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textDark,
        ),
      ),
      value: value,
      activeColor: AppColors.accent,
      onChanged: onChanged,
      dense: true,
    );
  }

  Widget _buildQuietHoursSection(NotificationPreferences prefs) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Quiet Hours',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(
              'Enable Quiet Hours',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textDark,
              ),
            ),
            subtitle: Text(
              'Silence notifications during set hours',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            value: prefs.quietHoursEnabled,
            activeColor: AppColors.accent,
            onChanged: (v) => _saveQuietHours(enabled: v),
            dense: true,
          ),
          if (prefs.quietHoursEnabled) ...[
            _buildTimeRow(
              'Start',
              prefs.quietHoursStart,
              (picked) => _saveQuietHours(start: picked),
            ),
            _buildTimeRow(
              'End',
              prefs.quietHoursEnd,
              (picked) => _saveQuietHours(end: picked),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeRow(
    String label,
    TimeOfDay value,
    ValueChanged<TimeOfDay> onPicked,
  ) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.textDark,
        ),
      ),
      trailing: Text(
        value.format(context),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
        );
        if (picked != null) onPicked(picked);
      },
    );
  }
}
