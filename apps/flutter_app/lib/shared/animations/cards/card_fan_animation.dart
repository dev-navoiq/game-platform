import 'dart:math';

import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Animates cards fanning out in the player's hand.
///
/// Layout follows `_context.md` CardFan spec:
/// - Spread: `min(36, 210 / (n-1))` px between card centres
/// - Rotation: `(index - (n-1)/2) * 4.5` degrees
/// - Y offset: `abs(offset) * 2.5` px drop for outer cards
/// - Selected card: `translateY(-20px)` with overshoot bounce
class CardFanAnimation extends StatefulWidget {
  final int cardCount;
  final int? selectedIndex;
  final Widget Function(int index) cardBuilder;
  final ValueChanged<int>? onCardTap;

  const CardFanAnimation({
    super.key,
    required this.cardCount,
    required this.cardBuilder,
    this.selectedIndex,
    this.onCardTap,
  });

  @override
  State<CardFanAnimation> createState() => _CardFanAnimationState();
}

class _CardFanAnimationState extends State<CardFanAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _entryControllers;
  late List<Animation<double>> _entryAnimations;
  AnimationController? _selectController;
  Animation<double>? _selectAnimation;

  @override
  void initState() {
    super.initState();
    _initEntryAnimations();
    _startEntrySequence();
  }

  void _initEntryAnimations() {
    _entryControllers = List.generate(widget.cardCount, (i) {
      return AnimationController(
        duration: AnimationDurations.cardDeal,
        vsync: this,
      );
    });

    _entryAnimations = _entryControllers.map((c) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: c, curve: AnimationCurves.cardDeal),
      );
    }).toList();
  }

  Future<void> _startEntrySequence() async {
    for (var i = 0; i < widget.cardCount; i++) {
      if (!mounted) return;
      _entryControllers[i].forward();
      if (i < widget.cardCount - 1) {
        await Future.delayed(AnimationDurations.cardEntryStagger);
      }
    }
  }

  @override
  void didUpdateWidget(CardFanAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cardCount != oldWidget.cardCount) {
      // Resize the entry-controllers list to match the new card count.
      // Without this, cards arriving after the first frame (e.g. on the
      // joiner who initially mounted with an empty hand) hit a RangeError
      // on `_entryControllers[-1]` and the whole game screen stops painting.
      // Only grow — when cards shrink during a round we leave existing
      // controllers in place so they can be reused on the next deal,
      // avoiding churn when hands cycle 8 → 0 → 8 between rounds.
      while (_entryControllers.length < widget.cardCount) {
        final c = AnimationController(
          duration: AnimationDurations.cardDeal,
          vsync: this,
        );
        _entryControllers.add(c);
        _entryAnimations.add(
          Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: c, curve: AnimationCurves.cardDeal),
          ),
        );
        c.forward();
      }
    }
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _animateSelection(widget.selectedIndex);
    }
  }

  void _animateSelection(int? index) {
    _selectController?.dispose();
    _selectController = null;
    _selectAnimation = null;
    if (index == null) {
      setState(() {});
      return;
    }

    _selectController = AnimationController(
      duration: AnimationDurations.cardSelect,
      vsync: this,
    );
    _selectAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _selectController!,
        curve: AnimationCurves.cardSelect,
      ),
    );
    _selectController!.forward();
    _selectController!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  double _cardSpread() {
    if (widget.cardCount <= 1) return 0;
    return min(36.0, 210.0 / (widget.cardCount - 1));
  }

  @override
  void dispose() {
    for (final c in _entryControllers) {
      c.dispose();
    }
    _selectController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spread = _cardSpread();
    const cardWidth = 62.0;

    return SizedBox(
      height: 130,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;

          return Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: List.generate(widget.cardCount, (i) {
              final normalizedOffset =
                  widget.cardCount > 1 ? (i - (widget.cardCount - 1) / 2) : 0.0;
              final xOffset = normalizedOffset * spread;
              final rotation = normalizedOffset * 4.5 * pi / 180;
              final yDrop = normalizedOffset.abs() * 2.5;

              final isSelected = widget.selectedIndex == i;
              final selectLift = isSelected && _selectAnimation != null
                  ? _selectAnimation!.value * -20
                  : 0.0;

              final entryProgress =
                  i < _entryAnimations.length ? _entryAnimations[i].value : 1.0;

              return AnimatedBuilder(
                animation: _entryControllers[min(i, _entryControllers.length - 1)],
                builder: (context, child) {
                  return Positioned(
                    left: centerX + xOffset - cardWidth / 2,
                    bottom: -yDrop + selectLift,
                    child: Opacity(
                      opacity: entryProgress,
                      child: Transform.rotate(
                        angle: rotation * entryProgress,
                        alignment: Alignment.bottomCenter,
                        child: Transform.scale(
                          scale: 0.8 + 0.2 * entryProgress,
                          child: GestureDetector(
                            onTap: () => widget.onCardTap?.call(i),
                            child: widget.cardBuilder(i),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          );
        },
      ),
    );
  }
}
