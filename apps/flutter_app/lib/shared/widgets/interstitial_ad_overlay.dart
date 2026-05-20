import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';
import 'glass_button.dart';

/// Fullscreen interstitial ad overlay with a 5-second skip timer
/// and subscription upsell prompt.
class InterstitialAdOverlay extends StatefulWidget {
  final int skipDelay;
  final VoidCallback onClose;
  final VoidCallback? onUpgrade;

  const InterstitialAdOverlay({
    super.key,
    this.skipDelay = 5,
    required this.onClose,
    this.onUpgrade,
  });

  static Future<void> show({
    required BuildContext context,
    int skipDelay = 5,
    VoidCallback? onUpgrade,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => InterstitialAdOverlay(
        skipDelay: skipDelay,
        onClose: () => Navigator.of(context).pop(),
        onUpgrade: onUpgrade,
      ),
    );
  }

  @override
  State<InterstitialAdOverlay> createState() => _InterstitialAdOverlayState();
}

class _InterstitialAdOverlayState extends State<InterstitialAdOverlay> {
  late int _secondsRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.skipDelay;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Ad content placeholder
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: AppColors.glassBorder.withOpacity(0.15),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ad_units,
                            size: 48,
                            color: AppColors.textMuted.withOpacity(0.4)),
                        const SizedBox(height: 8),
                        Text(
                          'Ad Placeholder',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Upsell
                if (widget.onUpgrade != null)
                  GestureDetector(
                    onTap: widget.onUpgrade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.accent.withOpacity(0.2),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Remove ads with Pro',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Skip button (top-right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _secondsRemaining > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: Text(
                      'Skip in ${_secondsRemaining}s',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  )
                : GlassButton(
                    label: 'Skip',
                    onPressed: widget.onClose,
                    variant: GlassButtonVariant.outlined,
                    size: GlassButtonSize.small,
                    color: Colors.white,
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
          ),
        ],
      ),
    );
  }
}
