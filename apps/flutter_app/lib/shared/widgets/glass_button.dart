import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/glass_tokens.dart';

enum GlassButtonVariant { filled, outlined, ghost }

enum GlassButtonSize { small, medium, large }

/// A glass-morphism styled button.
///
/// The original constructor contract is preserved: [label], [onPressed],
/// [isLoading], and [icon] all work exactly as before. New optional params
/// ([variant], [size], [color], [enableHaptics], [width]) allow richer usage
/// without breaking existing callers.
class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;

  // ── New optional params ─────────────────────────────────────
  final GlassButtonVariant variant;
  final GlassButtonSize size;
  final Color? color;
  final bool enableHaptics;
  final double? width;
  final BorderRadius? borderRadius;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = GlassButtonVariant.filled,
    this.size = GlassButtonSize.medium,
    this.color,
    this.enableHaptics = true,
    this.width,
    this.borderRadius,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  bool get _isDisabled => widget.onPressed == null;

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

  void _handleTapDown(TapDownDetails _) {
    if (_isDisabled || widget.isLoading) return;
    _controller.forward();
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) => _controller.reverse();
  void _handleTapCancel() => _controller.reverse();

  // ── Size configs ──────────────────────────────────────────────
  double get _height {
    switch (widget.size) {
      case GlassButtonSize.small:
        return 36;
      case GlassButtonSize.medium:
        return 44;
      case GlassButtonSize.large:
        return 56;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case GlassButtonSize.small:
        return 13;
      case GlassButtonSize.medium:
        return 14;
      case GlassButtonSize.large:
        return 16;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case GlassButtonSize.small:
        return 18;
      case GlassButtonSize.medium:
        return 20;
      case GlassButtonSize.large:
        return 24;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case GlassButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case GlassButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case GlassButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? GlassTokens.accentPrimary;
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(GlassTokens.radiusMedium);

    final double opacity = _isDisabled ? 0.5 : 1.0;

    // ── Content row ─────────────────────────────────────────────
    final bool isFilled = widget.variant == GlassButtonVariant.filled;
    final Color textColor = isFilled ? Colors.white : color;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(textColor),
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            widget.icon!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: _fontSize,
                color: textColor,
              ),
            ),
          ),
        ],
      ],
    );

    // ── Decorated container per variant ──────────────────────────
    Widget button;

    switch (widget.variant) {
      case GlassButtonVariant.filled:
        button = Container(
          height: _height,
          width: widget.width,
          padding: _padding,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.8)],
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

      case GlassButtonVariant.outlined:
        button = ClipRRect(
          borderRadius: effectiveBorderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: _height,
              width: widget.width,
              padding: _padding,
              decoration: BoxDecoration(
                borderRadius: effectiveBorderRadius,
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

      case GlassButtonVariant.ghost:
        button = Container(
          height: _height,
          width: widget.width,
          padding: _padding,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            color: _isHovered
                ? color.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Center(child: content),
        );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: (_isDisabled || widget.isLoading) ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(opacity: opacity, child: button),
          ),
        ),
      ),
    );
  }
}
