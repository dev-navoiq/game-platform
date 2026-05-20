import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// A speech bubble that floats above a player's avatar.
///
/// Auto-dismisses after 4 seconds. Three visual types:
/// - **Text**: white background, dark text
/// - **Emote-only**: large emoji, no background
/// - **Quick-phrase**: [AppColors.accentSoft] tinted background
///
/// Animation: scale(0.7→1) + fadeIn on entry; fadeOut + translateY(-8) on exit.
class FloatingChatBubble extends StatefulWidget {
  final String message;
  final bool isEmoteOnly;
  final bool isQuickPhrase;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const FloatingChatBubble({
    super.key,
    required this.message,
    this.isEmoteOnly = false,
    this.isQuickPhrase = false,
    this.onTap,
    this.onDismissed,
  });

  @override
  State<FloatingChatBubble> createState() => _FloatingChatBubbleState();
}

class _FloatingChatBubbleState extends State<FloatingChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    // Entry: 0–6% (250ms), Hold: 6–93%, Exit: 93–100% (300ms)
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.7, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 6,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 87),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 7,
      ),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 6),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 87),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 7),
    ]).animate(_controller);

    _slideAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: ConstantTween(Offset.zero), weight: 93),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -8)),
        weight: 7,
      ),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismissed?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Transform.translate(
        offset: _slideAnim.value,
        child: Opacity(
          opacity: _opacityAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: widget.isEmoteOnly
                ? Text(widget.message, style: const TextStyle(fontSize: 48))
                : GestureDetector(
                    onTap: widget.onTap,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isQuickPhrase
                            ? AppColors.accentSoft.withOpacity(0.25)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
