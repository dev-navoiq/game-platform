import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/history/data/history_repository.dart';

void main() {
  group('RecentGame', () {
    test('fromJson parses all fields', () {
      final game = RecentGame.fromJson({
        'id': 'abc-123',
        'game_type': 'chess',
        'room_id': 'room-456',
        'played_at': '2026-03-08T12:00:00Z',
        'duration_seconds': 1234,
        'result': 'win',
        'final_position': 1,
        'points_earned': 50,
        'elo_change': 15,
        'opponent_names': ['Alice', 'Bob'],
        'game_summary': {'key': 'val'},
      });

      expect(game.id, 'abc-123');
      expect(game.gameType, 'chess');
      expect(game.roomId, 'room-456');
      expect(game.playedAt, DateTime.utc(2026, 3, 8, 12));
      expect(game.durationSeconds, 1234);
      expect(game.result, 'win');
      expect(game.finalPosition, 1);
      expect(game.pointsEarned, 50);
      expect(game.eloChange, 15);
      expect(game.opponentNames, ['Alice', 'Bob']);
      expect(game.gameSummary, {'key': 'val'});
    });

    test('fromJson handles missing optional fields', () {
      final game = RecentGame.fromJson({
        'id': 'abc-123',
        'game_type': 'ludo',
        'played_at': '2026-03-08T12:00:00Z',
        'result': 'loss',
      });

      expect(game.roomId, isNull);
      expect(game.durationSeconds, isNull);
      expect(game.finalPosition, isNull);
      expect(game.pointsEarned, isNull);
      expect(game.eloChange, isNull);
      expect(game.opponentNames, isEmpty);
      expect(game.gameSummary, isNull);
    });

    test('fromJson defaults result to unknown when null', () {
      final game = RecentGame.fromJson({
        'id': 'abc',
        'game_type': 'chess',
        'played_at': '2026-03-08T12:00:00Z',
      });
      expect(game.result, 'unknown');
    });

    test('isWin / isLoss / isDraw', () {
      RecentGame make(String result) => RecentGame(
            id: '1',
            gameType: 'chess',
            playedAt: DateTime.now(),
            result: result,
            opponentNames: const [],
          );

      expect(make('win').isWin, true);
      expect(make('win').isLoss, false);
      expect(make('loss').isLoss, true);
      expect(make('draw').isDraw, true);
      expect(make('abandoned').isWin, false);
    });

    test('durationDisplay formats correctly', () {
      RecentGame make(int? seconds) => RecentGame(
            id: '1',
            gameType: 'chess',
            playedAt: DateTime.now(),
            result: 'win',
            durationSeconds: seconds,
            opponentNames: const [],
          );

      expect(make(null).durationDisplay, '--');
      expect(make(0).durationDisplay, '0m 0s');
      expect(make(65).durationDisplay, '1m 5s');
      expect(make(3600).durationDisplay, '60m 0s');
    });

    test('eloChangeDisplay formats correctly', () {
      RecentGame make(int? elo) => RecentGame(
            id: '1',
            gameType: 'chess',
            playedAt: DateTime.now(),
            result: 'win',
            eloChange: elo,
            opponentNames: const [],
          );

      expect(make(null).eloChangeDisplay, '--');
      expect(make(15).eloChangeDisplay, '+15');
      expect(make(-10).eloChangeDisplay, '-10');
      expect(make(0).eloChangeDisplay, '0');
    });
  });

  group('GameStats', () {
    test('empty returns all zeros', () {
      const stats = GameStats.empty;
      expect(stats.totalGames, 0);
      expect(stats.wins, 0);
      expect(stats.winRate, 0);
      expect(stats.winRateDisplay, '0.0%');
      expect(stats.avgDurationDisplay, '0m');
    });

    test('winRateDisplay formats percentage', () {
      const stats = GameStats(
        totalGames: 10,
        wins: 7,
        losses: 2,
        draws: 1,
        winRate: 0.7,
        totalPointsEarned: 100,
        averageGameDuration: 300,
        currentWinStreak: 3,
        bestWinStreak: 5,
      );

      expect(stats.winRateDisplay, '70.0%');
      expect(stats.avgDurationDisplay, '5m');
    });

    test('avgDurationDisplay rounds to minutes', () {
      const stats = GameStats(
        totalGames: 1,
        wins: 1,
        losses: 0,
        draws: 0,
        winRate: 1.0,
        totalPointsEarned: 0,
        averageGameDuration: 90,
        currentWinStreak: 1,
        bestWinStreak: 1,
      );

      expect(stats.avgDurationDisplay, '1m');
    });
  });
}
