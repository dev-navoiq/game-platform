import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/colors.dart';

class ReadyChip extends StatefulWidget {
  final String playerName;
  final bool isReady;
  final bool isBot;
  final double size;

  const ReadyChip({
    super.key,
    required this.playerName,
    required this.isReady,
    this.isBot = false,
    this.size = 28,
  });

  @override
  State<ReadyChip> createState() => _ReadyChipState();
}

class _ReadyChipState extends State<ReadyChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_scaleController);

    if (widget.isReady) {
      _scaleController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant ReadyChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isReady && widget.isReady) {
      _scaleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.isReady;
    final readyBg = Colors.green.shade400;
    const pendingBorder = AppColors.accent;

    final bg = ready ? readyBg : Colors.transparent;
    final border = ready
        ? Border.all(color: readyBg, width: 1.5)
        : Border.all(color: pendingBorder, width: 1.5);
    final textColor = ready ? Colors.white : Colors.white.withOpacity(0.6);

    final verticalPad = (widget.size - 18).clamp(2.0, 12.0) / 2;
    final horizontalPad = widget.size * 0.5;
    final iconSize = (widget.size * 0.5).clamp(12.0, 18.0);
    final fontSize = (widget.size * 0.45).clamp(11.0, 14.0);

    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: widget.size,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPad,
            vertical: verticalPad,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.size),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (ready) ...[
                Icon(
                  Icons.check_circle,
                  size: iconSize,
                  color: Colors.white,
                ),
                SizedBox(width: widget.size * 0.18),
              ],
              Flexible(
                child: Text(
                  widget.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (widget.isBot) ...[
                SizedBox(width: widget.size * 0.18),
                Container(
                  width: widget.size * 0.22,
                  height: widget.size * 0.22,
                  decoration: BoxDecoration(
                    color: (ready ? Colors.white : Colors.white)
                        .withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
