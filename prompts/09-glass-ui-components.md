# 08 - Glass UI Components

> Create a glass morphism design system for the game platform.

## Task

Build a comprehensive glass-style UI component library with:
- Frosted glass containers and cards
- Glowing borders and highlights
- Blur effects with transparency
- Animated glass surfaces
- Light/dark mode support
- Accessibility considerations

---

## Design Tokens

```dart
// lib/shared/theme/glass_tokens.dart

import 'dart:ui';
import 'package:flutter/material.dart';

/// Glass morphism design tokens
class GlassTokens {
  // Blur intensities
  static const double blurLight = 10.0;
  static const double blurMedium = 20.0;
  static const double blurHeavy = 40.0;

  // Opacities
  static const double surfaceOpacity = 0.15;
  static const double surfaceOpacityHover = 0.25;
  static const double surfaceOpacityPressed = 0.35;
  static const double borderOpacity = 0.2;

  // Border widths
  static const double borderThin = 0.5;
  static const double borderMedium = 1.0;
  static const double borderThick = 1.5;

  // Glow
  static const double glowRadius = 20.0;
  static const double glowIntensity = 0.5;

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXLarge = 32.0;
  static const double radiusRound = 999.0;

  // Animation durations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // Colors for light mode
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFFFFFFF);
  static const lightGlow = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1A1A2E);
  static const lightTextMuted = Color(0xFF6B7280);

  // Colors for dark mode
  static const darkSurface = Color(0xFF1A1A2E);
  static const darkBorder = Color(0xFFFFFFFF);
  static const darkGlow = Color(0xFF6366F1);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextMuted = Color(0xFF9CA3AF);

  // Accent colors
  static const accentPrimary = Color(0xFF6366F1); // Indigo
  static const accentSuccess = Color(0xFF10B981); // Emerald
  static const accentWarning = Color(0xFFF59E0B); // Amber
  static const accentError = Color(0xFFEF4444); // Red
  static const accentInfo = Color(0xFF3B82F6); // Blue
}
```

---

## Base Glass Container

```dart
// lib/shared/widgets/glass/glass_container.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass_tokens.dart';

/// A frosted glass container with blur effect
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color? surfaceColor;
  final Color? borderColor;
  final double borderWidth;
  final double surfaceOpacity;
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
    this.blur = GlassTokens.blurMedium,
    this.surfaceColor,
    this.borderColor,
    this.borderWidth = GlassTokens.borderMedium,
    this.surfaceOpacity = GlassTokens.surfaceOpacity,
    this.gradient,
    this.shadows,
    this.enableGlow = false,
    this.glowColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveSurfaceColor = surfaceColor ??
        (isDark ? GlassTokens.darkSurface : GlassTokens.lightSurface);

    final effectiveBorderColor = borderColor ??
        (isDark ? GlassTokens.darkBorder : GlassTokens.lightBorder);

    final effectiveGlowColor = glowColor ??
        (isDark ? GlassTokens.darkGlow : GlassTokens.lightGlow);

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: effectiveSurfaceColor.withOpacity(surfaceOpacity),
            gradient: gradient,
            border: Border.all(
              color: effectiveBorderColor.withOpacity(GlassTokens.borderOpacity),
              width: borderWidth,
            ),
            boxShadow: shadows ??
                (enableGlow
                    ? [
                        BoxShadow(
                          color: effectiveGlowColor.withOpacity(0.2),
                          blurRadius: GlassTokens.glowRadius,
                          spreadRadius: 0,
                        ),
                      ]
                    : null),
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
```

---

## Interactive Glass Button

```dart
// lib/shared/widgets/glass/glass_button.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/glass_tokens.dart';

enum GlassButtonVariant { filled, outlined, ghost }
enum GlassButtonSize { small, medium, large }

class GlassButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final GlassButtonSize size;
  final Color? color;
  final bool isLoading;
  final bool isDisabled;
  final bool enableHaptics;
  final double? width;
  final BorderRadius? borderRadius;

  const GlassButton({
    super.key,
    this.label,
    this.icon,
    this.iconWidget,
    this.onPressed,
    this.variant = GlassButtonVariant.filled,
    this.size = GlassButtonSize.medium,
    this.color,
    this.isLoading = false,
    this.isDisabled = false,
    this.enableHaptics = true,
    this.width,
    this.borderRadius,
  }) : assert(label != null || icon != null || iconWidget != null);

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: GlassTokens.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.isDisabled || widget.isLoading) return;
    setState(() => _isPressed = true);
    _controller.forward();
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(_) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.color ?? GlassTokens.accentPrimary;

    // Size configurations
    final double height;
    final double fontSize;
    final double iconSize;
    final EdgeInsets padding;

    switch (widget.size) {
      case GlassButtonSize.small:
        height = 36;
        fontSize = 14;
        iconSize = 18;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
        break;
      case GlassButtonSize.medium:
        height = 44;
        fontSize = 16;
        iconSize = 20;
        padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
        break;
      case GlassButtonSize.large:
        height = 56;
        fontSize = 18;
        iconSize = 24;
        padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
        break;
    }

    // Opacity based on state
    double opacity = 1.0;
    if (widget.isDisabled) {
      opacity = 0.5;
    } else if (_isPressed) {
      opacity = 0.8;
    }

    // Build content
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                widget.variant == GlassButtonVariant.filled
                    ? Colors.white
                    : color,
              ),
            ),
          ),
          if (widget.label != null) const SizedBox(width: 8),
        ] else if (widget.iconWidget != null) ...[
          widget.iconWidget!,
          if (widget.label != null) const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: iconSize,
            color: widget.variant == GlassButtonVariant.filled
                ? Colors.white
                : color,
          ),
          if (widget.label != null) const SizedBox(width: 8),
        ],
        if (widget.label != null)
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: widget.variant == GlassButtonVariant.filled
                  ? Colors.white
                  : color,
            ),
          ),
      ],
    );

    // Wrap in decoration based on variant
    Widget button;
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(GlassTokens.radiusMedium);

    switch (widget.variant) {
      case GlassButtonVariant.filled:
        button = Container(
          height: height,
          width: widget.width,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_isHovered ? 0.5 : 0.3),
                blurRadius: _isHovered ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: content),
        );
        break;

      case GlassButtonVariant.outlined:
        button = ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: height,
              width: widget.width,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: (_isHovered ? color : Colors.white)
                    .withOpacity(_isHovered ? 0.15 : 0.1),
                border: Border.all(
                  color: color.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Center(child: content),
            ),
          ),
        );
        break;

      case GlassButtonVariant.ghost:
        button = Container(
          height: height,
          width: widget.width,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: _isHovered ? color.withOpacity(0.1) : Colors.transparent,
          ),
          child: Center(child: content),
        );
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.isDisabled || widget.isLoading ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: opacity,
              child: button,
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Glass Card

```dart
// lib/shared/widgets/glass/glass_card.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass_tokens.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool enableHover;
  final bool enableGlow;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding,
    this.borderRadius = GlassTokens.radiusMedium,
    this.enableHover = true,
    this.enableGlow = false,
    this.glowColor,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.enableGlow) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = widget.glowColor ?? GlassTokens.accentPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return AnimatedContainer(
            duration: GlassTokens.durationMedium,
            transform: Matrix4.identity()
              ..translate(0.0, _isHovered && widget.enableHover ? -4.0 : 0.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                if (widget.enableGlow)
                  BoxShadow(
                    color: glowColor.withOpacity(_glowAnimation.value),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: _isHovered ? 20 : 10,
                  offset: Offset(0, _isHovered ? 10 : 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: GlassTokens.blurMedium,
                  sigmaY: GlassTokens.blurMedium,
                ),
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (isDark ? Colors.white : Colors.white)
                              .withOpacity(_isHovered ? 0.2 : 0.15),
                          (isDark ? Colors.white : Colors.white)
                              .withOpacity(_isHovered ? 0.1 : 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.white)
                            .withOpacity(_isHovered ? 0.3 : 0.2),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: widget.padding ??
                          const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title != null ||
                              widget.leading != null ||
                              widget.trailing != null) ...[
                            Row(
                              children: [
                                if (widget.leading != null) ...[
                                  widget.leading!,
                                  const SizedBox(width: 12),
                                ],
                                if (widget.title != null)
                                  Expanded(
                                    child: Text(
                                      widget.title!,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? GlassTokens.darkText
                                            : GlassTokens.lightText,
                                      ),
                                    ),
                                  ),
                                if (widget.trailing != null) widget.trailing!,
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          widget.child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

---

## Glass Input Field

```dart
// lib/shared/widgets/glass/glass_text_field.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass_tokens.dart';

class GlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool enabled;

  const GlassTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _isFocused = _focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null;

    final borderColor = hasError
        ? GlassTokens.accentError
        : _isFocused
            ? GlassTokens.accentPrimary
            : (isDark ? Colors.white : Colors.black).withOpacity(0.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? GlassTokens.darkTextMuted
                  : GlassTokens.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: GlassTokens.durationFast,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
                color: (isDark ? Colors.white : Colors.white)
                    .withOpacity(_isFocused ? 0.15 : 0.1),
                border: Border.all(
                  color: borderColor,
                  width: _isFocused ? 2 : 1,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: GlassTokens.accentPrimary.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                maxLines: widget.maxLines,
                enabled: widget.enabled,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? GlassTokens.darkText : GlassTokens.lightText,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: isDark
                        ? GlassTokens.darkTextMuted
                        : GlassTokens.lightTextMuted,
                  ),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _isFocused
                              ? GlassTokens.accentPrimary
                              : (isDark
                                  ? GlassTokens.darkTextMuted
                                  : GlassTokens.lightTextMuted),
                        )
                      : null,
                  suffix: widget.suffix,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: const TextStyle(
              fontSize: 12,
              color: GlassTokens.accentError,
            ),
          ),
        ],
      ],
    );
  }
}
```

---

## Glass Modal / Bottom Sheet

```dart
// lib/shared/widgets/glass/glass_bottom_sheet.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass_tokens.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? Colors.white : Colors.white).withOpacity(0.2),
                (isDark ? Colors.white : Colors.white).withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.white).withOpacity(0.2),
              width: 1,
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
                      color: (isDark ? Colors.white : Colors.black)
                          .withOpacity(0.3),
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
                              color: isDark
                                  ? GlassTokens.darkText
                                  : GlassTokens.lightText,
                            ),
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            onPressed: onClose,
                            icon: Icon(
                              Icons.close,
                              color: isDark
                                  ? GlassTokens.darkTextMuted
                                  : GlassTokens.lightTextMuted,
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
```

---

## Glass Navigation Bar

```dart
// lib/shared/widgets/glass/glass_nav_bar.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/glass_tokens.dart';

class GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavBarItem> items;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(GlassTokens.radiusLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: GlassTokens.blurHeavy,
              sigmaY: GlassTokens.blurHeavy,
            ),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GlassTokens.radiusLarge),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? Colors.white : Colors.white).withOpacity(0.2),
                    (isDark ? Colors.white : Colors.white).withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color:
                      (isDark ? Colors.white : Colors.white).withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;

                  return _NavItem(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onTap(index),
                    isDark: isDark,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const GlassNavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

class _NavItem extends StatelessWidget {
  final GlassNavBarItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _NavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? GlassTokens.accentPrimary
        : (isDark ? GlassTokens.darkTextMuted : GlassTokens.lightTextMuted);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: GlassTokens.durationMedium,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
          color: isSelected
              ? GlassTokens.accentPrimary.withOpacity(0.15)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? (item.activeIcon ?? item.icon) : item.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Usage Example

```dart
// Example: Game lobby with glass UI

class GameLobbyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image/gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header card
                  GlassCard(
                    title: 'Available Games',
                    leading: Icon(Icons.games, color: GlassTokens.accentPrimary),
                    enableGlow: true,
                    child: Text('Choose a game to play'),
                  ),

                  SizedBox(height: 16),

                  // Game list
                  Expanded(
                    child: ListView(
                      children: [
                        GlassCard(
                          onTap: () => navigateToGame('twenty_nine'),
                          child: ListTile(
                            leading: Icon(Icons.style),
                            title: Text('Twenty-Nine'),
                            subtitle: Text('4 players • Teams'),
                          ),
                        ),
                        // ... more games
                      ],
                    ),
                  ),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          label: 'Create Room',
                          icon: Icons.add,
                          variant: GlassButtonVariant.filled,
                          onPressed: () {},
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: GlassButton(
                          label: 'Join Room',
                          icon: Icons.login,
                          variant: GlassButtonVariant.outlined,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GlassNavBar(
        currentIndex: 0,
        onTap: (index) {},
        items: [
          GlassNavBarItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
          GlassNavBarItem(icon: Icons.games_outlined, activeIcon: Icons.games, label: 'Games'),
          GlassNavBarItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ],
      ),
    );
  }
}
```

---

## Expected Output

- Complete glass morphism component library
- GlassContainer, GlassButton, GlassCard, GlassTextField
- GlassBottomSheet, GlassNavBar, GlassAppBar
- Light/dark mode adaptive colors
- Hover and press animations
- Accessibility support (semantic labels, contrast)
- Comprehensive documentation and examples
