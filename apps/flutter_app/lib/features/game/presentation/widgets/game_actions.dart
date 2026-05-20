import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_button.dart';

/// Action buttons panel for the game screen (leave, settings, etc.).
class GameActions extends StatelessWidget {
  final VoidCallback? onLeave;
  final VoidCallback? onSettings;
  final bool isSpectator;

  const GameActions({
    super.key,
    this.onLeave,
    this.onSettings,
    this.isSpectator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassButton(
          label: isSpectator ? 'Leave' : 'Forfeit',
          onPressed: () => _confirmLeave(context),
          variant: GlassButtonVariant.outlined,
          size: GlassButtonSize.small,
        ),
        if (onSettings != null) ...[
          const SizedBox(width: 8),
          GlassButton(
            label: 'Settings',
            onPressed: onSettings,
            variant: GlassButtonVariant.ghost,
            size: GlassButtonSize.small,
          ),
        ],
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    if (isSpectator) {
      onLeave?.call();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.feltMid,
        title: Text(
          'Leave Game?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'You will forfeit if you leave now.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Stay', style: GoogleFonts.inter(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Leave', style: GoogleFonts.inter(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onLeave?.call();
    }
  }
}
