import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../core/animation_constants.dart';

/// Animated bid counter showing tricks won vs bid.
///
/// Scale-bounces on change and transitions colour:
/// neutral → success (making) → danger (busted).
class BidCounterAnimation extends StatefulWidget {
  final int current;
  final int bid;
  final bool isActive;

  const BidCounterAnimation({
    super.key,
    required this.current,
    required this.bid,
    this.isActive = true,
  });

  @override
  State<BidCounterAnimation> createState() => _BidCounterAnimationState();
}

class _BidCounterAnimationState extends State<BidCounterAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.bidCounter,
      vsync: this,
    );

    // TweenSequence domain is [0, 1]; easeOutBack overshoots that range
    // and would throw at evaluate time. The sequence below already gives
    // a 1.0 → 1.3 → 1.0 pop, so animate against the raw controller.
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3),
        weight: 0.4,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 0.6,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(BidCounterAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current != oldWidget.current) {
      _controller.forward(from: 0);
    }
  }

  Color get _statusColor {
    if (!widget.isActive) return Colors.white54;
    if (widget.current > widget.bid) return AppColors.danger;
    if (widget.current == widget.bid) return AppColors.success;
    return Colors.white54;
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
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedContainer(
            duration: AnimationDurations.bidCounter,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _statusColor, width: 1.5),
            ),
            child: Text(
              '${widget.current} / ${widget.bid}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _statusColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
