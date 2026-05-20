import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/feature_flag_providers.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/colors.dart';
import 'glass_button.dart';
import 'glass_container.dart';

/// A glass-styled banner that appears when an OTA update is available.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(updateStatusProvider);

    return statusAsync.when(
      data: (status) => _buildBanner(context, ref, status),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context, WidgetRef ref, UpdateStatus status) {
    if (status != UpdateStatus.updateAvailable &&
        status != UpdateStatus.readyToInstall &&
        status != UpdateStatus.downloading) {
      return const SizedBox.shrink();
    }

    final updateService = ref.read(updateServiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassContainer(
        borderRadius: 14,
        surfaceColor: AppColors.feltDark,
        surfaceOpacity: 0.85,
        borderColor: AppColors.accent.withOpacity(0.6),
        enableGlow: true,
        glowColor: AppColors.accent.withOpacity(0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              status == UpdateStatus.readyToInstall
                  ? Icons.restart_alt
                  : Icons.system_update_outlined,
              color: AppColors.accent,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    status == UpdateStatus.readyToInstall
                        ? 'Update Ready'
                        : status == UpdateStatus.downloading
                            ? 'Downloading…'
                            : 'Update Available',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    updateService.statusMessage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (status == UpdateStatus.updateAvailable)
              GlassButton(
                label: 'Update',
                onPressed: () async {
                  await updateService.downloadAndInstall();
                },
                size: GlassButtonSize.small,
                variant: GlassButtonVariant.filled,
              )
            else if (status == UpdateStatus.downloading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              )
            else if (status == UpdateStatus.readyToInstall)
              GlassButton(
                label: 'Restart',
                onPressed: () {
                  // App restart — would use a package like restart_app
                },
                size: GlassButtonSize.small,
                variant: GlassButtonVariant.filled,
              ),
          ],
        ),
      ),
    );
  }
}
