import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/under_construction_banner.dart';

/// Notification preferences with toggles matching the
/// `notification_preferences` table columns.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // Mirrors notification_preferences table columns
  bool _friendRequests = true;
  bool _gameInvites = true;
  bool _turnReminders = true;
  bool _chatMessages = true;
  bool _challengeUpdates = true;
  bool _seasonPassRewards = true;
  bool _promotions = false;
  bool _leaderboardChanges = true;
  bool _systemAlerts = true;

  // Quiet hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const UnderConstructionBanner(
            message:
                'Notification preferences are under construction — toggles below are not yet persisted to your account.',
          ),
          _buildSection('Game Notifications', [
            _buildToggle('Friend Requests', _friendRequests,
                (v) => setState(() => _friendRequests = v)),
            _buildToggle('Game Invites', _gameInvites,
                (v) => setState(() => _gameInvites = v)),
            _buildToggle('Turn Reminders', _turnReminders,
                (v) => setState(() => _turnReminders = v)),
            _buildToggle('Chat Messages', _chatMessages,
                (v) => setState(() => _chatMessages = v)),
          ]),
          const SizedBox(height: 16),
          _buildSection('Progress & Rewards', [
            _buildToggle('Challenge Updates', _challengeUpdates,
                (v) => setState(() => _challengeUpdates = v)),
            _buildToggle('Season Pass Rewards', _seasonPassRewards,
                (v) => setState(() => _seasonPassRewards = v)),
            _buildToggle('Leaderboard Changes', _leaderboardChanges,
                (v) => setState(() => _leaderboardChanges = v)),
          ]),
          const SizedBox(height: 16),
          _buildSection('Other', [
            _buildToggle('Promotions & Offers', _promotions,
                (v) => setState(() => _promotions = v)),
            _buildToggle('System Alerts', _systemAlerts,
                (v) => setState(() => _systemAlerts = v)),
          ]),
          const SizedBox(height: 16),
          _buildQuietHoursSection(),
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

  Widget _buildQuietHoursSection() {
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
            value: _quietHoursEnabled,
            activeColor: AppColors.accent,
            onChanged: (v) => setState(() => _quietHoursEnabled = v),
            dense: true,
          ),
          if (_quietHoursEnabled) ...[
            ListTile(
              dense: true,
              title: Text(
                'Start',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              trailing: Text(
                _quietStart.format(context),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _quietStart,
                );
                if (picked != null) {
                  setState(() => _quietStart = picked);
                }
              },
            ),
            ListTile(
              dense: true,
              title: Text(
                'End',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textDark,
                ),
              ),
              trailing: Text(
                _quietEnd.format(context),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _quietEnd,
                );
                if (picked != null) {
                  setState(() => _quietEnd = picked);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
