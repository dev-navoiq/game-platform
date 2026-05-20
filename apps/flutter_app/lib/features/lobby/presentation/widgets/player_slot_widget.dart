import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_card.dart';

/// A glass-styled player slot for the room waiting screen.
class PlayerSlotWidget extends StatelessWidget {
  final String? playerName;
  final bool isHost;
  final bool isBot;
  final bool isReady;
  final bool isEmpty;
  final Color? playerColor;

  const PlayerSlotWidget({
    super.key,
    this.playerName,
    this.isHost = false,
    this.isBot = false,
    this.isReady = false,
    this.isEmpty = false,
    this.playerColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return _EmptySlot();
    }

    final color = playerColor ?? AppColors.accent;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enableHover: false,
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
              border: Border.all(
                color: color.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: isBot
                  ? Icon(Icons.smart_toy, size: 20, color: color)
                  : Text(
                      (playerName ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (isHost || isBot) ...[
                  const SizedBox(height: 2),
                  Text(
                    isHost ? 'Host' : 'Bot',
                    style: TextStyle(
                      fontSize: 11,
                      color: isHost ? AppColors.accent : AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Ready indicator
          if (isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.success.withOpacity(0.15),
              ),
              child: Text(
                'Ready',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.glassBorder.withOpacity(0.3),
          width: 1,
          style: BorderStyle.solid,
        ),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: Icon(
              Icons.person_add_outlined,
              size: 20,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Waiting for player...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
