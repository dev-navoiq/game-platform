import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';

/// A frosted glass card with optional title, leading/trailing widgets,
/// hover-lift animation, and pulsing glow.
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
    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
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
    final glowColor = widget.glowColor ?? GlassTokens.accentPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, _) {
          return AnimatedContainer(
            duration: GlassTokens.durationMedium,
            transform: Matrix4.identity()
              ..translate(
                  0.0, _isHovered && widget.enableHover ? -4.0 : 0.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                if (widget.enableGlow)
                  BoxShadow(
                    color: glowColor.withOpacity(_glowAnimation.value),
                    blurRadius: 30,
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
                  sigmaX: GlassTokens.blurDefault,
                  sigmaY: GlassTokens.blurDefault,
                ),
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(widget.borderRadius),
                      color: Colors.white.withOpacity(
                          _isHovered ? 0.58 : GlassTokens.surfaceOpacity),
                      border: Border.all(
                        color: AppColors.glassBorder,
                        width: GlassTokens.borderMedium,
                      ),
                    ),
                    child: Padding(
                      padding:
                          widget.padding ?? const EdgeInsets.all(16),
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
                                        color: AppColors.textDark,
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
