import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Visual deck shuffle (riffle) effect.
///
/// Two halves of the deck interleave with slight offset and rotation,
/// then converge back to a centred stack.
class ShuffleAnimation extends StatefulWidget {
  final double cardWidth;
  final double cardHeight;
  final VoidCallback? onComplete;

  const ShuffleAnimation({
    super.key,
    required this.cardWidth,
    required this.cardHeight,
    this.onComplete,
  });

  @override
  State<ShuffleAnimation> createState() => _ShuffleAnimationState();
}

class _ShuffleAnimationState extends State<ShuffleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _splitAnimation;
  late Animation<double> _riffleAnimation;
  late Animation<double> _mergeAnimation;

  static const _halfCount = 5;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AnimationDurations.shuffle,
      vsync: this,
    );

    // Phase 1: Split deck in two halves
    _splitAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    // Phase 2: Riffle interleave
    _riffleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.7, curve: Curves.easeInOut),
    );

    // Phase 3: Merge back
    _mergeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.7, 1.0, curve: AnimationCurves.smoothOut),
    );

    _controller.forward().then((_) => widget.onComplete?.call());
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
        return SizedBox(
          width: widget.cardWidth + 60,
          height: widget.cardHeight + 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left half
              for (var i = 0; i < _halfCount; i++) _buildCard(i, isLeft: true),

              // Right half
              for (var i = 0; i < _halfCount; i++)
                _buildCard(i, isLeft: false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(int index, {required bool isLeft}) {
    final splitOffset = isLeft ? -30.0 : 30.0;
    final splitX = splitOffset * _splitAnimation.value;

    // During riffle, cards interleave vertically
    final riffleY =
        isLeft ? -index * 2.0 * _riffleAnimation.value : index * 2.0 * _riffleAnimation.value;
    final riffleRotation = (isLeft ? -0.05 : 0.05) * _riffleAnimation.value;

    // Merge back to centre
    final mergeX = splitX * (1 - _mergeAnimation.value);
    final mergeY = riffleY * (1 - _mergeAnimation.value);
    final mergeRotation = riffleRotation * (1 - _mergeAnimation.value);

    return Transform.translate(
      offset: Offset(mergeX, mergeY + index * 0.5),
      child: Transform.rotate(
        angle: mergeRotation,
        child: Container(
          width: widget.cardWidth,
          height: widget.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1a1a2a),
            border: Border.all(color: Colors.white24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
