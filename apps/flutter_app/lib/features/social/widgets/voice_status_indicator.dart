import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:social_core/social_core.dart';

import '../../../core/theme/colors.dart';
import '../../../shared/widgets/glass_container.dart';
import '../providers/social_providers.dart';

/// Glass pill showing voice chat status.
///
/// Hidden when voice is not allowed for the current social mode.
/// Shows "Voice chat coming soon" with a mic icon while [StubVoiceService]
/// is in use.
class VoiceStatusIndicator extends ConsumerWidget {
  final RoomSocialMode socialMode;

  const VoiceStatusIndicator({
    super.key,
    required this.socialMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ChatRules.isVoiceAllowed(socialMode)) {
      return const SizedBox.shrink();
    }

    final voiceService = ref.watch(voiceServiceProvider);
    return StreamBuilder<VoiceState>(
      stream: voiceService.stateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isConnected =
            state?.status == VoiceConnectionStatus.connected;

        return GlassContainer(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isConnected ? Icons.mic : Icons.mic_off,
                size: 14,
                color: isConnected
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? 'Voice Connected' : 'Voice chat coming soon',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
