import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';

/// A glass-morphism styled text field with focus glow and error state.
class GlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const GlassTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        setState(() => _isFocused = _focusNode.hasFocus);
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    final borderColor = hasError
        ? GlassTokens.danger
        : _isFocused
            ? GlassTokens.accentPrimary
            : AppColors.glassBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
          child: AnimatedContainer(
            // Fully opaque white so dark text always reads cleanly over the
            // dark felt background. Earlier glass-blur + 0.88/0.95 white
            // mixed with the felt and the entered text was still hard to
            // see — particularly while pasting a room code. The BackdropFilter
            // was removed because it does nothing visually behind an opaque
            // surface and was costing a render pass.
            duration: GlassTokens.durationFast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
              color: Colors.white,
              border: Border.all(
                color: borderColor,
                width: _isFocused ? 2 : 1,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: GlassTokens.accentPrimary
                            .withOpacity(0.25),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                maxLines: widget.maxLines,
                enabled: widget.enabled,
                inputFormatters: widget.inputFormatters,
                textCapitalization: widget.textCapitalization,
                cursorColor: GlassTokens.accentPrimary,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  // The app's inputDecorationTheme sets `filled: true,
                  // fillColor: cardDark` for dark mode, which would paint
                  // over our white AnimatedContainer and make the dark text
                  // unreadable on Android in auto-dark mode. Force filled
                  // off here so the white container shows through.
                  filled: false,
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withOpacity(0.85),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _isFocused
                              ? GlassTokens.accentPrimary
                              : AppColors.textMuted,
                        )
                      : null,
                  suffix: widget.suffix,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: const TextStyle(
              fontSize: 12,
              color: GlassTokens.danger,
            ),
          ),
        ],
      ],
    );
  }
}
