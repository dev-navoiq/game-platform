import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_card.dart';

/// A glass-styled card representing a room in the lobby list.
class RoomListCard extends StatelessWidget {
  final String roomCode;
  final String hostName;
  final int playerCount;
  final int maxPlayers;
  final String socialMode;
  final VoidCallback onTap;

  const RoomListCard({
    super.key,
    required this.roomCode,
    required this.hostName,
    required this.playerCount,
    required this.maxPlayers,
    required this.socialMode,
    required this.onTap,
  });

  IconData get _socialModeIcon {
    switch (socialMode) {
      case 'full':
        return Icons.mic;
      case 'chat_only':
        return Icons.chat_bubble_outline;
      case 'silent':
        return Icons.volume_off;
      case 'focus':
        return Icons.visibility;
      default:
        return Icons.mic;
    }
  }

  String get _socialModeLabel {
    switch (socialMode) {
      case 'full':
        return 'Full';
      case 'chat_only':
        return 'Chat';
      case 'silent':
        return 'Silent';
      case 'focus':
        return 'Focus';
      default:
        return 'Full';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Room code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.accent.withOpacity(0.15),
            ),
            child: Text(
              roomCode,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Host + player count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$playerCount / $maxPlayers players',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Social mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_socialModeIcon, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  _socialModeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
