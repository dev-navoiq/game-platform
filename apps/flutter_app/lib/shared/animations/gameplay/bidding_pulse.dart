import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class BiddingPulse extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Color? color;

  const BiddingPulse({
    super.key,
    required this.child,
    required this.isActive,
    this.color,
  });

  @override
  State<BiddingPulse> createState() => _BiddingPulseState();
}

class _BiddingPulseState extends State<BiddingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant BiddingPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: always return the SAME widget tree shape regardless of
    // isActive. Returning `widget.child` directly when inactive and a
    // wrapped widget when active changes the element-tree shape on toggle,
    // which forces Flutter to unmount + remount the child subtree. For
    // CardHand-as-child, that destroyed CardFanAnimation's State on every
    // bid turn during the bidding phase — the staggered card-deal-in
    // animation restarted, often mid-animation, so cards were stuck
    // invisible until the next interaction.
    final pulseColor = widget.color ?? AppColors.accent;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final shadows = widget.isActive
            ? <BoxShadow>[
                BoxShadow(
                  color: pulseColor.withOpacity(0.25 + 0.40 * _curve.value),
                  blurRadius: 12.0 + 16.0 * _curve.value,
                  spreadRadius: 6.0 * _curve.value,
                ),
              ]
            : const <BoxShadow>[];
        return DecoratedBox(
          decoration: BoxDecoration(boxShadow: shadows),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
