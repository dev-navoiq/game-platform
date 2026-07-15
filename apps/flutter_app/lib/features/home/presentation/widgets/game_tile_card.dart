import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../game_visuals.dart';

/// A glass-styled game tile for the home screen grid.
///
/// Prefers per-game art when available, with a soft idle float animation.
class GameTileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final int? onlinePlayers;
  final VoidCallback onTap;
  final String? gameType;
  final int animationIndex;

  const GameTileCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = AppColors.accent,
    this.onlinePlayers,
    required this.onTap,
    this.gameType,
    this.animationIndex = 0,
  });

  factory GameTileCard.fromType({
    Key? key,
    required String gameType,
    required VoidCallback onTap,
    String? title,
    String? subtitle,
    int? onlinePlayers,
    int animationIndex = 0,
  }) {
    final visual = GameVisuals.of(gameType);
    return GameTileCard(
      key: key,
      gameType: gameType,
      title: title ?? visual.title,
      subtitle: subtitle ?? visual.subtitle,
      icon: visual.fallbackIcon,
      iconColor: visual.accentColor,
      onlinePlayers: onlinePlayers,
      onTap: onTap,
      animationIndex: animationIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = gameType != null ? GameVisuals.of(gameType!) : null;
    final accent = visual?.accentColor ?? iconColor;
    final asset = visual?.imageAsset;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              GlassTokens.glassShadow,
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GlassTokens.radiusMedium),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: GlassTokens.blurDefault,
                sigmaY: GlassTokens.blurDefault,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.glass.withValues(
                    alpha: GlassTokens.surfaceOpacity,
                  ),
                  borderRadius:
                      BorderRadius.circular(GlassTokens.radiusMedium),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: GlassTokens.borderMedium,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _GameArtPanel(
                        asset: asset,
                        icon: icon,
                        accent: accent,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              height: 1.15,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (onlinePlayers != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$onlinePlayers online',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return tile
        .animate()
        .fadeIn(
          duration: 380.ms,
          delay: (40 * animationIndex).ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 420.ms,
          delay: (40 * animationIndex).ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _GameArtPanel extends StatelessWidget {
  final String? asset;
  final IconData icon;
  final Color accent;

  const _GameArtPanel({
    required this.asset,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final art = asset != null
        ? Image.asset(
            asset!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) =>
                _FallbackIcon(icon: icon, accent: accent),
          )
        : _FallbackIcon(icon: icon, accent: accent);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(GlassTokens.radiusMedium - 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          art
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.05, 1.05),
                duration: 2800.ms,
                curve: Curves.easeInOut,
              )
              .moveY(
                begin: 0,
                end: -3,
                duration: 2800.ms,
                curve: Curves.easeInOut,
              ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFF8F0).withValues(alpha: 0.0),
                    const Color(0xFFFFF8F0).withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _FallbackIcon({required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.18),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 32, color: accent),
      ),
    );
  }
}
