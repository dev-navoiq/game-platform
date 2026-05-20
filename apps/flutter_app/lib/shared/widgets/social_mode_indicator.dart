import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../../core/theme/colors.dart';
import 'glass_container.dart';

/// Displays the social mode of a room with an icon and optional label.
///
/// Wraps content in a [GlassContainer] for glass-morphism effect.
class SocialModeIndicator extends StatelessWidget {
  final RoomSocialMode mode;
  final bool showLabel;
  final double iconSize;

  const SocialModeIndicator({
    super.key,
    required this.mode,
    this.showLabel = true,
    this.iconSize = 16,
  });

  IconData get _icon {
    switch (mode) {
      case RoomSocialMode.full:
        return Icons.volume_up;
      case RoomSocialMode.chatOnly:
        return Icons.chat_bubble_outline;
      case RoomSocialMode.silent:
        return Icons.volume_off;
      case RoomSocialMode.focus:
        return Icons.center_focus_strong;
    }
  }

  String get _label {
    switch (mode) {
      case RoomSocialMode.full:
        return 'Full';
      case RoomSocialMode.chatOnly:
        return 'Chat Only';
      case RoomSocialMode.silent:
        return 'Silent';
      case RoomSocialMode.focus:
        return 'Focus';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 100,
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 10 : 8,
        vertical: 5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: iconSize, color: AppColors.accent),
          if (showLabel) ...[
            const SizedBox(width: 5),
            Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
