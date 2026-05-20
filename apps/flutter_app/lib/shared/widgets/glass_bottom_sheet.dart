import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';

/// A glass-morphism styled modal bottom sheet.
///
/// Use the static [show] method for convenience:
/// ```dart
/// GlassBottomSheet.show(context: context, child: MyContent());
/// ```
class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showDragHandle;
  final bool enableDismiss;
  final VoidCallback? onClose;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.enableDismiss = true,
    this.onClose,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool showDragHandle = true,
    bool enableDismiss = true,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      isDismissible: enableDismiss,
      enableDrag: enableDismiss,
      builder: (context) => GlassBottomSheet(
        title: title,
        showDragHandle: showDragHandle,
        enableDismiss: enableDismiss,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(GlassTokens.radiusXLarge),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTokens.blurHeavy,
          sigmaY: GlassTokens.blurHeavy,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(GlassTokens.radiusXLarge),
            ),
            color: Colors.white.withOpacity(GlassTokens.surfaceOpacity),
            border: Border.all(
              color: AppColors.glassBorder,
              width: GlassTokens.borderMedium,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            onPressed: onClose,
                            icon: Icon(
                              Icons.close,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
