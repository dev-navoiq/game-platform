import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_card.dart';

/// A glass-styled player slot for the room waiting screen.
///
/// When [isEmpty] is true AND [onAddBot] is provided, the slot renders three
/// difficulty icons (Easy / Medium / Hard) so the host can pick a bot to
/// drop into that seat without leaving the lobby. While a bot is being
/// added, the row is replaced with a spinner via [isAddingBot].
class PlayerSlotWidget extends StatelessWidget {
  final String? playerName;
  final bool isHost;
  final bool isBot;
  final bool isReady;
  final bool isEmpty;
  final Color? playerColor;
  // Host-only: callback invoked with 'easy' | 'medium' | 'hard' when a
  // difficulty icon is tapped on an empty slot. Null on non-host clients
  // (which fall back to the dim "Waiting for player..." text).
  final ValueChanged<String>? onAddBot;
  // While the addBot RPC is in flight for this slot the icons are replaced
  // with a centered spinner so the user gets immediate ack on the tap
  // without accidentally double-adding.
  final bool isAddingBot;

  const PlayerSlotWidget({
    super.key,
    this.playerName,
    this.isHost = false,
    this.isBot = false,
    this.isReady = false,
    this.isEmpty = false,
    this.playerColor,
    this.onAddBot,
    this.isAddingBot = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return _EmptySlot(
        onAddBot: onAddBot,
        isAddingBot: isAddingBot,
      );
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
  final ValueChanged<String>? onAddBot;
  final bool isAddingBot;

  const _EmptySlot({this.onAddBot, this.isAddingBot = false});

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
          Expanded(child: _buildTrailing()),
        ],
      ),
    );
  }

  Widget _buildTrailing() {
    if (isAddingBot) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Adding bot…',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );
    }

    if (onAddBot == null) {
      // Non-host view: just the "waiting" hint, can't add bots.
      return Text(
        'Waiting for player...',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textMuted.withOpacity(0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _DifficultyIcon(
          icon: Icons.sentiment_satisfied,
          color: AppColors.success,
          tooltip: 'Easy bot',
          onTap: () => onAddBot!('easy'),
        ),
        const SizedBox(width: 8),
        _DifficultyIcon(
          icon: Icons.psychology,
          color: AppColors.accent,
          tooltip: 'Medium bot',
          onTap: () => onAddBot!('medium'),
        ),
        const SizedBox(width: 8),
        _DifficultyIcon(
          icon: Icons.local_fire_department,
          color: AppColors.danger,
          tooltip: 'Hard bot',
          onTap: () => onAddBot!('hard'),
        ),
      ],
    );
  }
}

class _DifficultyIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _DifficultyIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
