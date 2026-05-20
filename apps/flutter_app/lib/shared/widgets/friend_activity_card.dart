import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';
import 'glass_card.dart';

/// Activity status for a friend on the platform.
enum FriendActivityStatus { inGame, inLobby, online, offline }

/// Displays a friend's current activity in a compact card (~100px wide)
/// suitable for a horizontal `ListView`.
///
/// States:
/// - In Game (green dot, "Watch" button)
/// - In Lobby (amber dot, "Join" button)
/// - Online (blue dot, "Invite" button)
/// - Offline (grey dot, dimmed)
class FriendActivityCard extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final FriendActivityStatus status;
  final String? gameType;
  final String? statusDetail;
  final VoidCallback? onAction;
  final String? roomId;

  const FriendActivityCard({
    super.key,
    required this.displayName,
    this.avatarUrl,
    required this.status,
    this.gameType,
    this.statusDetail,
    this.onAction,
    this.roomId,
  });

  Color get _statusColor {
    switch (status) {
      case FriendActivityStatus.inGame:
        return AppColors.success;
      case FriendActivityStatus.inLobby:
        return GlassTokens.warning;
      case FriendActivityStatus.online:
        return GlassTokens.info;
      case FriendActivityStatus.offline:
        return AppColors.textMuted;
    }
  }

  String get _actionLabel {
    switch (status) {
      case FriendActivityStatus.inGame:
        return 'Watch';
      case FriendActivityStatus.inLobby:
        return 'Join';
      case FriendActivityStatus.online:
        return 'Invite';
      case FriendActivityStatus.offline:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = status == FriendActivityStatus.offline;

    return Opacity(
      opacity: isOffline ? 0.5 : 1.0,
      child: SizedBox(
        width: 100,
        child: GlassCard(
          padding: const EdgeInsets.all(10),
          borderRadius: GlassTokens.radiusMedium,
          enableHover: !isOffline,
          onTap: isOffline ? null : onAction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status dot + avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accentSoft.withOpacity(0.3),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Name
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),

              // Game / status detail
              if (gameType != null || statusDetail != null) ...[
                const SizedBox(height: 2),
                Text(
                  gameType ?? statusDetail ?? '',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
              if (statusDetail != null && gameType != null) ...[
                Text(
                  statusDetail!,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],

              // Action button
              if (!isOffline && _actionLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _actionLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
