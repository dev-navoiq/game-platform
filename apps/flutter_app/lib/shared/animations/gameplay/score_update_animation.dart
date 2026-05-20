import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../core/animation_constants.dart';

/// Score change animation with old value sliding out and new sliding in.
///
/// An optional "+N" delta floats up and fades.
class ScoreUpdateAnimation extends StatefulWidget {
  final int score;
  final int? delta;
  final Color? color;

  const ScoreUpdateAnimation({
    super.key,
    required this.score,
    this.delta,
    this.color,
  });

  @override
  State<ScoreUpdateAnimation> createState() => _ScoreUpdateAnimationState();
}

class _ScoreUpdateAnimationState extends State<ScoreUpdateAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _oldSlide;
  late Animation<Offset> _newSlide;
  late Animation<double> _oldOpacity;
  late Animation<double> _newOpacity;
  late Animation<Offset> _deltaSlide;
  late Animation<double> _deltaOpacity;

  int _displayScore = 0;
  int _previousScore = 0;

  @override
  void initState() {
    super.initState();
    _displayScore = widget.score;
    _previousScore = widget.score;

    _controller = AnimationController(
      duration: AnimationDurations.scoreUpdate,
      vsync: this,
    );

    _setupAnimations();
  }

  void _setupAnimations() {
    // Old score slides up and fades out
    _oldSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeIn),
    ));

    _oldOpacity = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4),
    ));

    // New score slides up from below
    _newSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1, curve: Curves.easeOut),
    ));

    _newOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8),
    ));

    // Delta floats up
    _deltaSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _deltaOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 0.2),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 0.4),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 0.4),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(ScoreUpdateAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.score != oldWidget.score) {
      _previousScore = oldWidget.score;
      _displayScore = widget.score;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.textOnFelt;
    final scoreStyle = GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_controller.isAnimating) {
          return Text('$_displayScore', style: scoreStyle);
        }

        return ClipRect(
          child: SizedBox(
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Old score sliding out
                SlideTransition(
                  position: _oldSlide,
                  child: Opacity(
                    opacity: _oldOpacity.value,
                    child: Text('$_previousScore', style: scoreStyle),
                  ),
                ),

                // New score sliding in
                SlideTransition(
                  position: _newSlide,
                  child: Opacity(
                    opacity: _newOpacity.value,
                    child: Text('$_displayScore', style: scoreStyle),
                  ),
                ),

                // Delta floating up
                if (widget.delta != null)
                  Positioned(
                    right: -30,
                    child: SlideTransition(
                      position: _deltaSlide,
                      child: Opacity(
                        opacity: _deltaOpacity.value,
                        child: Text(
                          '+${widget.delta}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
