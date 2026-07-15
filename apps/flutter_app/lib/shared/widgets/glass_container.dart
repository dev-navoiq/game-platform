import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';

/// A frosted glass container with blur effect.
///
/// Uses the project's "Refined Crystal" glass recipe by default:
/// `rgba(255,255,255,0.52)` background, `rgba(255,255,255,0.72)` border,
/// and sigma-18 blur.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? surfaceColor;
  final double? surfaceOpacity;
  final Color? borderColor;
  final double borderWidth;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final bool enableGlow;
  final Color? glowColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = GlassTokens.radiusMedium,
    this.blur = GlassTokens.blurDefault,
    this.surfaceColor,
    this.surfaceOpacity,
    this.borderColor,
    this.borderWidth = GlassTokens.borderMedium,
    this.gradient,
    this.shadows,
    this.enableGlow = false,
    this.glowColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSurfaceColor = surfaceColor ?? const Color(0xFFFFF8F0);
    final effectiveOpacity =
        surfaceOpacity ?? GlassTokens.surfaceOpacity; // 0.72
    final effectiveBorderColor = borderColor ?? AppColors.glassBorder;
    final effectiveGlowColor = glowColor ?? GlassTokens.accentGlow;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: gradient == null
                ? effectiveSurfaceColor.withOpacity(effectiveOpacity)
                : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: effectiveBorderColor,
              width: borderWidth,
            ),
            boxShadow: shadows ??
                [
                  GlassTokens.glassShadow,
                  if (enableGlow)
                    BoxShadow(
                      color: effectiveGlowColor,
                      blurRadius: GlassTokens.glowRadius,
                    ),
                ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null || onLongPress != null) {
      content = GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: content,
      );
    }

    return content;
  }
}
