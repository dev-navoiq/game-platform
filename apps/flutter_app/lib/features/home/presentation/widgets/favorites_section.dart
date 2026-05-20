import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../favorites/providers/favorites_providers.dart';
import '../../../history/providers/history_providers.dart';

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
        // Favorites row
        if (favorites.isNotEmpty) ...[
          _SectionHeader(
            title: 'Favorites',
            icon: Icons.star,
            iconColor: Colors.amber,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
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
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Recently played row
        if (recentGames.isNotEmpty) ...[
          _SectionHeader(
            title: 'Recently Played',
            icon: Icons.history,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
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

// ── Private widgets ─────────────────────────────────────────────────────────

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
    return GlassContainer(
      width: 140,
      borderRadius: 16,
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getGameIcon(gameType),
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                _getDisplayName(gameType),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                _getSubtitle(gameType),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onFavoriteToggle,
              child: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : Colors.white54,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _getGameIcon(String gameType) {
    switch (gameType) {
      case 'twenty_nine':
        return Icons.style;
      case 'oh_hell':
        return Icons.whatshot;
      case 'hearts':
        return Icons.favorite;
      case 'spades':
        return Icons.eco;
      case 'chess':
        return Icons.castle;
      case 'ludo':
        return Icons.grid_view;
      case 'sequence':
        return Icons.apps;
      default:
        return Icons.games;
    }
  }

  static String _getDisplayName(String gameType) {
    switch (gameType) {
      case 'twenty_nine':
        return 'Twenty-Nine';
      case 'oh_hell':
        return 'Oh Hell';
      case 'hearts':
        return 'Hearts';
      case 'spades':
        return 'Spades';
      case 'chess':
        return 'Chess';
      case 'ludo':
        return 'Ludo';
      case 'sequence':
        return 'Sequence';
      default:
        return gameType;
    }
  }

  static String _getSubtitle(String gameType) {
    switch (gameType) {
      case 'twenty_nine':
      case 'hearts':
      case 'spades':
        return '4 players';
      case 'oh_hell':
        return '3-7 players';
      case 'chess':
        return '2 players';
      case 'ludo':
      case 'sequence':
        return '2-4 players';
      default:
        return '';
    }
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnFelt,
          ),
        ),
      ],
    );
  }
}
