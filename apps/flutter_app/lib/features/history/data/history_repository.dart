import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

/// A single completed game from the player's history.
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

  /// Reward receipt (rows since 2026-08-04 carry these; older rows null).
  final int? coinsEarned;
  final int? xpEarned;

  const RecentGame({
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
    this.coinsEarned,
    this.xpEarned,
  });

  factory RecentGame.fromJson(Map<String, dynamic> json) {
    return RecentGame(
      id: json['id'] as String,
      gameType: json['game_type'] as String,
      roomId: json['room_id'] as String?,
      playedAt: DateTime.parse(json['played_at'] as String),
      durationSeconds: json['duration_seconds'] as int?,
      result: json['result'] as String? ?? 'unknown',
      finalPosition: json['final_position'] as int?,
      pointsEarned: json['points_earned'] as int?,
      eloChange: json['elo_change'] as int?,
      opponentNames:
          List<String>.from(json['opponent_names'] as List? ?? []),
      gameSummary: json['game_summary'] as Map<String, dynamic>?,
      coinsEarned: json['coins_earned'] as int?,
      xpEarned: json['xp_earned'] as int?,
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
  bool get isDraw => result == 'draw';
}

/// Aggregated stats for a player (optionally filtered by game type).
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

  const GameStats({
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

  static const empty = GameStats(
    totalGames: 0,
    wins: 0,
    losses: 0,
    draws: 0,
    winRate: 0,
    totalPointsEarned: 0,
    averageGameDuration: 0,
    currentWinStreak: 0,
    bestWinStreak: 0,
  );
}

// ─── Repository ─────────────────────────────────────────────────────────────

/// Repository for querying game history and computing stats.
class HistoryRepository {
  final SupabaseClient _supabase;
  final String _userId;

  HistoryRepository({
    required SupabaseClient supabase,
    required String userId,
  })  : _supabase = supabase,
        _userId = userId;

  /// Fetch paginated recent games, optionally filtered by [gameType].
  Future<List<RecentGame>> getRecentGames({
    int limit = 20,
    int offset = 0,
    String? gameType,
  }) async {
    var filter = _supabase
        .from('recent_games')
        .select()
        .eq('user_id', _userId);

    if (gameType != null) {
      filter = filter.eq('game_type', gameType);
    }

    final response = await filter
        .order('played_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map((r) => RecentGame.fromJson(r)).toList();
  }

  /// Distinct game types the player has recently played.
  Future<List<String>> getRecentlyPlayedGameTypes({int limit = 5}) async {
    final response = await _supabase
        .from('recent_games')
        .select('game_type')
        .eq('user_id', _userId)
        .order('played_at', ascending: false)
        .limit(limit * 3); // fetch extra rows to dedupe

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

  /// Compute aggregate stats for the player.
  Future<GameStats> getStats({String? gameType}) async {
    var query = _supabase
        .from('recent_games')
        .select()
        .eq('user_id', _userId);

    if (gameType != null) {
      query = query.eq('game_type', gameType);
    }

    final response = await query;

    if (response.isEmpty) return GameStats.empty;

    int wins = 0;
    int losses = 0;
    int draws = 0;
    int totalPoints = 0;
    int totalDuration = 0;
    int currentStreak = 0;
    int bestStreak = 0;
    bool streakActive = true;

    for (final game in response) {
      final result = game['result'] as String?;

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

    final totalGames = response.length;

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

  /// Load full replay data for a completed game.
  Future<Map<String, dynamic>?> getGameReplay(String roomId) async {
    final moves = await _supabase
        .from('game_moves')
        .select()
        .eq('room_id', roomId)
        .order('sequence_number', ascending: true);

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
