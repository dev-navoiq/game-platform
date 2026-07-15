import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../theme/glass_tokens.dart';

/// A glass-morphism styled app bar.
///
/// Sits atop the screen with a frosted blur background. Matches the
/// "Refined Crystal" design language.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final double height;
  final bool centerTitle;

  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.height = 56,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTokens.blurDefault,
          sigmaY: GlassTokens.blurDefault,
        ),
        child: Container(
          height: height + topPadding,
          padding: EdgeInsets.only(top: topPadding),
          decoration: BoxDecoration(
            color: AppColors.glass.withValues(
              alpha: GlassTokens.surfaceOpacity,
            ),
            border: Border(
              bottom: BorderSide(
                color: AppColors.glassBorder,
                width: GlassTokens.borderThin,
              ),
            ),
            boxShadow: const [GlassTokens.glassShadow],
          ),
          child: NavigationToolbar(
            leading: leading ??
                (Navigator.canPop(context)
                    ? IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.textDark,
                          size: 20,
                        ),
                      )
                    : null),
            middle: titleWidget ??
                (title != null
                    ? Text(
                        title!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      )
                    : null),
            trailing: actions != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  )
                : null,
            centerMiddle: centerTitle,
          ),
        ),
      ),
    );
  }
}
