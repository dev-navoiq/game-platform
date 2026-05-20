import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';

/// Glass-styled toast message for game events.
///
/// Auto-dismisses after [displayDuration] with a fade/scale animation.
class GameToast extends StatefulWidget {
  final String message;
  final Duration displayDuration;
  final VoidCallback? onDismissed;

  const GameToast({
    super.key,
    required this.message,
    this.displayDuration = const Duration(seconds: 3),
    this.onDismissed,
  });

  @override
  State<GameToast> createState() => _GameToastState();
}

class _GameToastState extends State<GameToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.displayDuration,
      vsync: this,
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.92, end: 1.0)
            .chain(CurveTween(curve: const Cubic(0.34, 1.56, 0.64, 1))),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.92)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onDismissed?.call());
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
      builder: (_, __) => Opacity(
        opacity: _opacityAnim.value,
        child: Transform.scale(
          scale: _scaleAnim.value,
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Text(
              widget.message,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
