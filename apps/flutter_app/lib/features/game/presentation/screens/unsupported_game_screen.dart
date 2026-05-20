import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../widgets/game_table.dart';

/// "Coming Soon" placeholder screen for games not yet fully implemented
/// (Bridge, Rummy, etc.).
class UnsupportedGameScreen extends StatelessWidget {
  final String gameType;
  final VoidCallback? onLeave;

  const UnsupportedGameScreen({
    super.key,
    required this.gameType,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return GameTable(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 64,
                color: AppColors.accent.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                _displayName(gameType),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming Soon',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This game is under development.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 32),
              if (onLeave != null)
                ElevatedButton(
                  onPressed: onLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayName(String type) {
    switch (type) {
      case 'bridge':
        return 'Bridge';
      case 'rummy':
        return 'Rummy';
      default:
        return type.replaceAll('_', ' ').split(' ').map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1)}';
        }).join(' ');
    }
  }
}
