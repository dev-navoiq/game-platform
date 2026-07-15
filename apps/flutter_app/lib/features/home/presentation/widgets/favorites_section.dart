import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/theme/glass_tokens.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../favorites/providers/favorites_providers.dart';
import '../../../history/providers/history_providers.dart';
import '../game_visuals.dart';

/// Horizontal sections on the home screen for favorites and recently played.
class FavoritesSection extends ConsumerWidget {
  const FavoritesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final recentAsync = ref.watch(recentGameTypesProvider);
    final recentGames = recentAsync.valueOrNull ?? [];

    if (favorites.isEmpty && recentGames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (favorites.isNotEmpty) ...[
          const _SectionHeader(
            title: 'Favorites',
            icon: Icons.star_rounded,
            iconColor: Color(0xFFE8A84F),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _FavoriteGameCard(
                  gameType: favorites[index],
                  isFavorite: true,
                  onTap: () =>
                      context.push(AppRoutes.lobbyPath(favorites[index])),
                  onFavoriteToggle: () => ref
                      .read(favoritesProvider.notifier)
                      .toggle(favorites[index]),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (50 * index).ms)
                    .slideX(
                      begin: 0.06,
                      end: 0,
                      duration: 320.ms,
                      delay: (50 * index).ms,
                    );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (recentGames.isNotEmpty) ...[
          const _SectionHeader(
            title: 'Recently Played',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentGames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isFav = favorites.contains(recentGames[index]);
                return _FavoriteGameCard(
                  gameType: recentGames[index],
                  isFavorite: isFav,
                  onTap: () =>
                      context.push(AppRoutes.lobbyPath(recentGames[index])),
                  onFavoriteToggle: () => ref
                      .read(favoritesProvider.notifier)
                      .toggle(recentGames[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _FavoriteGameCard extends StatelessWidget {
  final String gameType;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _FavoriteGameCard({
    required this.gameType,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final visual = GameVisuals.of(gameType);

    return GlassContainer(
      width: 148,
      borderRadius: 16,
      onTap: onTap,
      // Explicit warm elevated glass — never white-on-glass.
      surfaceColor: const Color(0xFFFFF8F0),
      surfaceOpacity: 0.78,
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: visual.imageAsset != null
                      ? Image.asset(
                          visual.imageAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _IconBadge(visual: visual),
                        )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.05, 1.05),
                            duration: 2600.ms,
                            curve: Curves.easeInOut,
                          )
                      : _IconBadge(visual: visual),
                ),
              ),
              const Spacer(),
              Text(
                visual.title,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                visual.subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black.withValues(alpha: 0.25),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onFavoriteToggle,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavorite
                        ? GlassTokens.accentSoft
                        : Colors.white.withValues(alpha: 0.9),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final GameVisual visual;

  const _IconBadge({required this.visual});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: visual.accentColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          visual.fallbackIcon,
          color: visual.accentColor,
          size: 28,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppColors.textFeltMuted, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnFelt,
          ),
        ),
      ],
    );
  }
}
