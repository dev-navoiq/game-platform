# 16 - Favorites, Recent Games & History

> Implement favorite games, recently played tracking, and game history with replay capability.

## Task

Build features for:
- Marking games as favorites
- Recently played games list
- Complete game history with stats
- Game replay viewer
- Personal statistics dashboard

---

## Database Schema

```sql
-- Add to migrations

-- User favorite games
CREATE TABLE user_favorites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  game_type game_type NOT NULL,
  favorited_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, game_type)
);

-- Recently played (automatically tracked)
CREATE TABLE recent_games (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  game_type game_type NOT NULL,
  room_id UUID REFERENCES game_rooms(id) ON DELETE SET NULL,
  played_at TIMESTAMPTZ DEFAULT NOW(),
  duration_seconds INT,
  result TEXT, -- 'win', 'loss', 'draw', 'abandoned'
  final_position INT, -- 1st, 2nd, 3rd, etc. for free-for-all
  points_earned INT,
  elo_change INT,

  -- Denormalized for quick display
  opponent_names TEXT[],
  game_summary JSONB
);

CREATE INDEX idx_recent_games_user ON recent_games(user_id, played_at DESC);

-- RLS
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE recent_games ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own favorites" ON user_favorites
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users see own recent games" ON recent_games
  FOR SELECT USING (user_id = auth.uid());

-- Function to record game completion
CREATE OR REPLACE FUNCTION record_game_completion(
  p_room_id UUID,
  p_game_type game_type,
  p_results JSONB -- Array of {user_id, result, position, points, elo_change}
)
RETURNS VOID AS $$
DECLARE
  result_row JSONB;
  player_names TEXT[];
BEGIN
  -- Get opponent names for each player
  SELECT ARRAY_AGG(p.username)
  INTO player_names
  FROM room_players rp
  JOIN profiles p ON rp.user_id = p.id
  WHERE rp.room_id = p_room_id;

  -- Insert recent game record for each player
  FOR result_row IN SELECT * FROM jsonb_array_elements(p_results)
  LOOP
    INSERT INTO recent_games (
      user_id,
      game_type,
      room_id,
      result,
      final_position,
      points_earned,
      elo_change,
      opponent_names
    ) VALUES (
      (result_row->>'user_id')::UUID,
      p_game_type,
      p_room_id,
      result_row->>'result',
      (result_row->>'position')::INT,
      (result_row->>'points')::INT,
      (result_row->>'elo_change')::INT,
      player_names
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;
```

---

## Favorites Service

```dart
// lib/features/favorites/data/favorites_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesRepository {
  final SupabaseClient _supabase;
  final String _userId;

  FavoritesRepository({
    required SupabaseClient supabase,
    required String userId,
  })  : _supabase = supabase,
        _userId = userId;

  Future<List<String>> getFavoriteGames() async {
    final response = await _supabase
        .from('user_favorites')
        .select('game_type')
        .eq('user_id', _userId)
        .order('favorited_at', ascending: false);

    return response.map((r) => r['game_type'] as String).toList();
  }

  Future<bool> isFavorite(String gameType) async {
    final response = await _supabase
        .from('user_favorites')
        .select('id')
        .eq('user_id', _userId)
        .eq('game_type', gameType)
        .maybeSingle();

    return response != null;
  }

  Future<void> addFavorite(String gameType) async {
    await _supabase.from('user_favorites').upsert({
      'user_id': _userId,
      'game_type': gameType,
    });
  }

  Future<void> removeFavorite(String gameType) async {
    await _supabase
        .from('user_favorites')
        .delete()
        .eq('user_id', _userId)
        .eq('game_type', gameType);
  }

  Future<void> toggleFavorite(String gameType) async {
    if (await isFavorite(gameType)) {
      await removeFavorite(gameType);
    } else {
      await addFavorite(gameType);
    }
  }
}
```

---

## Recent Games & History

```dart
// lib/features/history/data/history_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class RecentGame {
  final String id;
  final String gameType;
  final String? roomId;
  final DateTime playedAt;
  final int? durationSeconds;
  final String result;
  final int? finalPosition;
  final int? pointsEarned;
  final int? eloChange;
  final List<String> opponentNames;
  final Map<String, dynamic>? gameSummary;

  RecentGame({
    required this.id,
    required this.gameType,
    this.roomId,
    required this.playedAt,
    this.durationSeconds,
    required this.result,
    this.finalPosition,
    this.pointsEarned,
    this.eloChange,
    required this.opponentNames,
    this.gameSummary,
  });

  factory RecentGame.fromJson(Map<String, dynamic> json) {
    return RecentGame(
      id: json['id'] as String,
      gameType: json['game_type'] as String,
      roomId: json['room_id'] as String?,
      playedAt: DateTime.parse(json['played_at'] as String),
      durationSeconds: json['duration_seconds'] as int?,
      result: json['result'] as String,
      finalPosition: json['final_position'] as int?,
      pointsEarned: json['points_earned'] as int?,
      eloChange: json['elo_change'] as int?,
      opponentNames: List<String>.from(json['opponent_names'] as List? ?? []),
      gameSummary: json['game_summary'] as Map<String, dynamic>?,
    );
  }

  String get durationDisplay {
    if (durationSeconds == null) return '--';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes}m ${seconds}s';
  }

  String get eloChangeDisplay {
    if (eloChange == null) return '--';
    if (eloChange! > 0) return '+$eloChange';
    return '$eloChange';
  }

  bool get isWin => result == 'win';
  bool get isLoss => result == 'loss';
}

class HistoryRepository {
  final SupabaseClient _supabase;
  final String _userId;

  HistoryRepository({
    required SupabaseClient supabase,
    required String userId,
  })  : _supabase = supabase,
        _userId = userId;

  Future<List<RecentGame>> getRecentGames({
    int limit = 20,
    int offset = 0,
    String? gameType,
  }) async {
    var query = _supabase
        .from('recent_games')
        .select()
        .eq('user_id', _userId)
        .order('played_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query;
    return response.map((r) => RecentGame.fromJson(r)).toList();
  }

  Future<List<String>> getRecentlyPlayedGameTypes({int limit = 5}) async {
    final response = await _supabase
        .from('recent_games')
        .select('game_type')
        .eq('user_id', _userId)
        .order('played_at', ascending: false)
        .limit(limit * 3); // Get more to dedupe

    final gameTypes = <String>[];
    for (final row in response) {
      final type = row['game_type'] as String;
      if (!gameTypes.contains(type)) {
        gameTypes.add(type);
        if (gameTypes.length >= limit) break;
      }
    }
    return gameTypes;
  }

  Future<GameStats> getStats({String? gameType}) async {
    var query = _supabase
        .from('recent_games')
        .select()
        .eq('user_id', _userId);

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query;

    int totalGames = response.length;
    int wins = 0;
    int losses = 0;
    int draws = 0;
    int totalPoints = 0;
    int totalDuration = 0;
    int currentStreak = 0;
    int bestStreak = 0;
    bool streakActive = true;

    for (final game in response) {
      final result = game['result'] as String;

      if (result == 'win') {
        wins++;
        if (streakActive) {
          currentStreak++;
          if (currentStreak > bestStreak) bestStreak = currentStreak;
        }
      } else {
        if (result == 'loss') losses++;
        if (result == 'draw') draws++;
        streakActive = false;
      }

      totalPoints += (game['points_earned'] as int?) ?? 0;
      totalDuration += (game['duration_seconds'] as int?) ?? 0;
    }

    return GameStats(
      totalGames: totalGames,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: totalGames > 0 ? wins / totalGames : 0,
      totalPointsEarned: totalPoints,
      averageGameDuration: totalGames > 0 ? totalDuration ~/ totalGames : 0,
      currentWinStreak: currentStreak,
      bestWinStreak: bestStreak,
    );
  }

  Future<Map<String, dynamic>?> getGameReplay(String roomId) async {
    // Get all moves for replay
    final moves = await _supabase
        .from('game_moves')
        .select()
        .eq('room_id', roomId)
        .order('sequence_number', ascending: true);

    // Get initial state
    final history = await _supabase
        .from('game_history')
        .select()
        .eq('room_id', roomId)
        .maybeSingle();

    if (history == null) return null;

    return {
      'game_info': history,
      'moves': moves,
    };
  }
}

class GameStats {
  final int totalGames;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final int totalPointsEarned;
  final int averageGameDuration;
  final int currentWinStreak;
  final int bestWinStreak;

  GameStats({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.totalPointsEarned,
    required this.averageGameDuration,
    required this.currentWinStreak,
    required this.bestWinStreak,
  });

  String get winRateDisplay => '${(winRate * 100).toStringAsFixed(1)}%';

  String get avgDurationDisplay {
    final minutes = averageGameDuration ~/ 60;
    return '${minutes}m';
  }
}
```

---

## Favorites & Recent UI

```dart
// lib/features/home/presentation/widgets/favorites_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoritesSection extends ConsumerWidget {
  const FavoritesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final recentGames = ref.watch(recentGameTypesProvider);

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
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _GameCard(
                  gameType: favorites[index],
                  isFavorite: true,
                  onTap: () => _navigateToGame(context, favorites[index]),
                  onFavoriteToggle: () => ref
                      .read(favoritesProvider.notifier)
                      .toggle(favorites[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Recently played
        if (recentGames.isNotEmpty) ...[
          _SectionHeader(
            title: 'Recently Played',
            icon: Icons.history,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recentGames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final isFav = favorites.contains(recentGames[index]);
                return _GameCard(
                  gameType: recentGames[index],
                  isFavorite: isFav,
                  onTap: () => _navigateToGame(context, recentGames[index]),
                  onFavoriteToggle: () => ref
                      .read(favoritesProvider.notifier)
                      .toggle(recentGames[index]),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _navigateToGame(BuildContext context, String gameType) {
    context.go('/lobby?game=$gameType');
  }
}

class _GameCard extends StatelessWidget {
  final String gameType;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _GameCard({
    required this.gameType,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final config = GameRegistry.getFactory(gameType)?.config;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(
          children: [
            // Game info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
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
                    config?.displayName ?? gameType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${config?.minPlayers}-${config?.maxPlayers} players',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Favorite button
            Positioned(
              top: 8,
              right: 8,
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
      ),
    );
  }

  IconData _getGameIcon(String gameType) {
    switch (gameType) {
      case 'twenty_nine':
      case 'oh_hell':
      case 'hearts':
      case 'spades':
        return Icons.style;
      case 'chess':
        return Icons.castle;
      case 'ludo':
        return Icons.casino;
      default:
        return Icons.games;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Game History Screen

```dart
// lib/features/history/presentation/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedGameType;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recent Games'),
            Tab(text: 'Statistics'),
          ],
        ),
        actions: [
          // Game filter
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedGameType = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Games'),
              ),
              ...GameRegistry.availableGames.map((config) => PopupMenuItem(
                value: config.gameId,
                child: Text(config.displayName),
              )),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecentGamesTab(gameType: _selectedGameType),
          _StatisticsTab(gameType: _selectedGameType),
        ],
      ),
    );
  }
}

class _RecentGamesTab extends ConsumerWidget {
  final String? gameType;

  const _RecentGamesTab({this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentGames = ref.watch(recentGamesProvider(gameType));

    return recentGames.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (games) {
        if (games.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.white30),
                SizedBox(height: 16),
                Text(
                  'No games played yet',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: games.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _GameHistoryCard(game: games[index]);
          },
        );
      },
    );
  }
}

class _GameHistoryCard extends StatelessWidget {
  final RecentGame game;

  const _GameHistoryCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: game.isWin
              ? Colors.green.withOpacity(0.3)
              : game.isLoss
                  ? Colors.red.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Result badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getResultColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  game.result.toUpperCase(),
                  style: TextStyle(
                    color: _getResultColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                GameRegistry.getFactory(game.gameType)?.config.displayName ??
                    game.gameType,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(game.playedAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _StatChip(
                icon: Icons.timer,
                value: game.durationDisplay,
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.stars,
                value: '${game.pointsEarned ?? 0}',
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.trending_up,
                value: game.eloChangeDisplay,
                valueColor: (game.eloChange ?? 0) >= 0
                    ? Colors.green
                    : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Opponents
          Text(
            'vs ${game.opponentNames.join(", ")}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),

          // Replay button
          if (game.roomId != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _openReplay(context, game.roomId!),
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Watch Replay'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getResultColor() {
    switch (game.result) {
      case 'win':
        return Colors.green;
      case 'loss':
        return Colors.red;
      case 'draw':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _openReplay(BuildContext context, String roomId) {
    context.push('/replay/$roomId');
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? valueColor;

  const _StatChip({
    required this.icon,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StatisticsTab extends ConsumerWidget {
  final String? gameType;

  const _StatisticsTab({this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(gameStatsProvider(gameType));

    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Win rate card
              _StatsCard(
                title: 'Win Rate',
                value: stats.winRateDisplay,
                icon: Icons.emoji_events,
                color: Colors.amber,
                subtitle: '${stats.wins}W - ${stats.losses}L - ${stats.draws}D',
              ),

              const SizedBox(height: 16),

              // Grid of stats
              Row(
                children: [
                  Expanded(
                    child: _StatsCard(
                      title: 'Total Games',
                      value: '${stats.totalGames}',
                      icon: Icons.games,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatsCard(
                      title: 'Points Earned',
                      value: '${stats.totalPointsEarned}',
                      icon: Icons.stars,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _StatsCard(
                      title: 'Win Streak',
                      value: '${stats.currentWinStreak}',
                      icon: Icons.local_fire_department,
                      color: Colors.orange,
                      subtitle: 'Best: ${stats.bestWinStreak}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatsCard(
                      title: 'Avg Duration',
                      value: stats.avgDurationDisplay,
                      icon: Icons.timer,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

---

## Expected Output

- Favorite games with persistent storage
- Recently played tracking
- Complete game history with filtering
- Statistics dashboard with win rate, streaks, etc.
- Game replay capability (moves stored)
- UI components for favorites and history sections
