import 'dart:math';

import 'package:flutter/material.dart';

import '../core/animation_constants.dart';
import '../core/animation_curves.dart';

/// Horizontal card strip used as the player's hand.
///
/// Layout:
/// - Cards are top-aligned (no fan rotation, no Y-drop).
/// - Adjacent cards overlap by [_overlap] so a 13-card hand stays dense.
/// - Strip is centered when content fits; scrolls horizontally otherwise.
/// - When [selectedIndex] is non-null, that card lifts by [_selectedLift].
/// - Cards enter with a staggered scale-up (0.85 → 1.0).
///
/// The class name is kept from the older fan-layout era to avoid a
/// codebase-wide rename. Behaviourally it is a strip, not a fan.
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

  // ── Layout constants (visible to game screens for height sizing) ──
  static const double cardWidth = 80;
  static const double cardHeight = 112;
  static const double overlap = 30;
  static const double selectedLift = 14;
  static const double stride = cardWidth - overlap; // 50 px between card lefts
  static const double stripHeight = cardHeight + selectedLift + 4; // 130

  @override
  State<CardFanAnimation> createState() => _CardFanAnimationState();
}

class _CardFanAnimationState extends State<CardFanAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _entryControllers;
  late List<Animation<double>> _entryAnimations;
  AnimationController? _selectController;
  Animation<double>? _selectAnimation;
  final ScrollController _scrollController = ScrollController();

  // Scroll affordance: which edge has off-screen content. Without these
  // cues a 13-card hand looks identical to a 5-card hand — the user has no
  // signal that swiping reveals more.
  bool _hasLeftOverflow = false;
  bool _hasRightOverflow = false;

  @override
  void initState() {
    super.initState();
    _initEntryAnimations();
    _startEntrySequence();
    _scrollController.addListener(_updateOverflowFromScroll);
    _scheduleOverflowCheck();
  }

  void _scheduleOverflowCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateOverflowFromScroll();
    });
  }

  void _updateOverflowFromScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // 2px tolerance avoids flicker at bounce extremes.
    final newLeft = pos.pixels > 2;
    final newRight = pos.pixels < pos.maxScrollExtent - 2;
    if (newLeft != _hasLeftOverflow || newRight != _hasRightOverflow) {
      setState(() {
        _hasLeftOverflow = newLeft;
        _hasRightOverflow = newRight;
      });
    }
  }

  void _initEntryAnimations() {
    _entryControllers = List.generate(widget.cardCount, (_) {
      return AnimationController(
        duration: AnimationDurations.cardDeal,
        vsync: this,
      );
    });
    _entryAnimations = _entryControllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: c, curve: AnimationCurves.cardDeal),
            ))
        .toList();
  }

  Future<void> _startEntrySequence() async {
    // Snapshot target up-front so a mid-deal hand shrink doesn't strand
    // controllers at value=0 (which would render as invisible cards).
    final target = widget.cardCount;
    for (var i = 0; i < target; i++) {
      if (!mounted) return;
      if (i < _entryControllers.length) {
        _entryControllers[i].forward();
      }
      if (i < target - 1) {
        await Future.delayed(AnimationDurations.cardEntryStagger);
      }
    }
    if (!mounted) return;
    for (var i = 0; i < _entryControllers.length; i++) {
      if (_entryControllers[i].value == 0) {
        _entryControllers[i].value = 1;
      }
    }
  }

  @override
  void didUpdateWidget(CardFanAnimation old) {
    super.didUpdateWidget(old);
    if (widget.cardCount != old.cardCount) {
      // Fresh deal (0 → N): wipe + re-stagger so cards animate in.
      final isNewDeal = old.cardCount == 0 && widget.cardCount > 0;
      if (isNewDeal) {
        for (final c in _entryControllers) {
          c.value = 0;
        }
        while (_entryControllers.length < widget.cardCount) {
          _addController();
        }
        _startEntrySequence();
      } else {
        // Mid-round shrink (card played) or hand grew without going to 0:
        // ensure every visible slot has a controller and is at value=1.
        while (_entryControllers.length < widget.cardCount) {
          final c = _addController();
          c.forward();
        }
        for (var i = 0; i < widget.cardCount && i < _entryControllers.length; i++) {
          if (_entryControllers[i].value == 0) {
            _entryControllers[i].value = 1;
          }
        }
      }
    }
    if (widget.selectedIndex != old.selectedIndex) {
      _animateSelection(widget.selectedIndex);
    }
    if (widget.cardCount != old.cardCount) {
      // Hand size changed → scroll extent likely changed → recompute the
      // edge-fade state once the new layout has settled.
      _scheduleOverflowCheck();
    }
  }

  AnimationController _addController() {
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
    return c;
  }

  /// Edge-fade affordance. Applies a horizontal gradient mask that fades
  /// out the side(s) where more content sits off-screen. No mask is applied
  /// when the hand fits entirely in the viewport — keeps the small-hand
  /// rendering pixel-identical to before.
  Widget _wrapWithEdgeFade(Widget child) {
    if (!_hasLeftOverflow && !_hasRightOverflow) return child;
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _hasLeftOverflow ? Colors.transparent : Colors.white,
            Colors.white,
            Colors.white,
            _hasRightOverflow ? Colors.transparent : Colors.white,
          ],
          stops: const [0.0, 0.10, 0.90, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
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

  @override
  void dispose() {
    for (final c in _entryControllers) {
      c.dispose();
    }
    _selectController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cardCount == 0) {
      return const SizedBox(height: CardFanAnimation.stripHeight);
    }

    final contentWidth = CardFanAnimation.stride * (widget.cardCount - 1) +
        CardFanAnimation.cardWidth;

    return SizedBox(
      height: CardFanAnimation.stripHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final needsScroll = contentWidth > viewportWidth;
          final horizPad = needsScroll
              ? 0.0
              : max(0.0, (viewportWidth - contentWidth) / 2);

          final strip = SizedBox(
            width: contentWidth,
            height: CardFanAnimation.stripHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(widget.cardCount, (i) {
                return AnimatedBuilder(
                  animation: _entryControllers[
                      min(i, _entryControllers.length - 1)],
                  builder: (context, child) {
                    final isSelected = widget.selectedIndex == i;
                    final entryProgress = i < _entryAnimations.length
                        ? _entryAnimations[i].value
                        : 1.0;
                    final entryScale = 0.85 + 0.15 * entryProgress;
                    final selectProgress =
                        isSelected && _selectAnimation != null
                            ? _selectAnimation!.value
                            : 0.0;
                    final topY = CardFanAnimation.selectedLift *
                        (1 - selectProgress);
                    return Positioned(
                      left: i * CardFanAnimation.stride,
                      top: topY,
                      child: Transform.scale(
                        scale: entryScale,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onCardTap?.call(i),
                          child: widget.cardBuilder(i),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          );

          // After this build commits, the controller will have its
          // position attached; schedule an overflow read so the fade
          // appears on the first frame after the hand grows past the
          // viewport.
          if (needsScroll) _scheduleOverflowCheck();

          final scrollView = SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: needsScroll
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: horizPad),
            child: strip,
          );

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              _wrapWithEdgeFade(scrollView),
              if (_hasLeftOverflow)
                const Positioned(
                  left: 2,
                  top: 0,
                  bottom: 0,
                  child: _ScrollChevron(direction: _ChevronDirection.left),
                ),
              if (_hasRightOverflow)
                const Positioned(
                  right: 2,
                  top: 0,
                  bottom: 0,
                  child: _ScrollChevron(direction: _ChevronDirection.right),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _ChevronDirection { left, right }

/// Static chevron icon at a scroll edge. IgnorePointer so it never swallows
/// taps on the underlying card. We chose static-not-pulsing for v1 because
/// a `repeat()` controller never settles, which breaks any widget test
/// that drives with `pumpAndSettle()`. If a pulse is wanted later, the
/// callsite can drive it from an external Listenable.
class _ScrollChevron extends StatelessWidget {
  final _ChevronDirection direction;

  const _ScrollChevron({required this.direction});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Icon(
          direction == _ChevronDirection.left
              ? Icons.chevron_left
              : Icons.chevron_right,
          size: 24,
          color: Colors.white.withOpacity(0.75),
          shadows: const [
            Shadow(
              color: Color(0x80000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
