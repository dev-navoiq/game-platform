import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/tournaments/data/tournament_models.dart';

void main() {
  group('TournamentFormat', () {
    test('fromDb maps all values correctly', () {
      expect(TournamentFormat.fromDb('single_elimination'),
          TournamentFormat.singleElimination);
      expect(TournamentFormat.fromDb('double_elimination'),
          TournamentFormat.doubleElimination);
      expect(TournamentFormat.fromDb('round_robin'),
          TournamentFormat.roundRobin);
      expect(TournamentFormat.fromDb('swiss'), TournamentFormat.swiss);
      expect(TournamentFormat.fromDb('multi_stage'),
          TournamentFormat.multiStage);
    });

    test('displayName returns readable name', () {
      expect(TournamentFormat.singleElimination.displayName,
          'Single Elimination');
      expect(TournamentFormat.roundRobin.displayName, 'Round Robin');
    });
  });

  group('TournamentStatus', () {
    test('fromDb maps all values', () {
      for (final status in TournamentStatus.values) {
        expect(TournamentStatus.fromDb(status.dbValue), status);
      }
    });
  });

  group('TournamentPrize', () {
    test('fromJson parses correctly', () {
      final prize = TournamentPrize.fromJson({
        'place': 1,
        'coins': 1000,
        'gems': 50,
        'skin_id': 'champion_card',
        'title': 'Champion',
      });

      expect(prize.place, 1);
      expect(prize.coins, 1000);
      expect(prize.gems, 50);
      expect(prize.skinId, 'champion_card');
      expect(prize.title, 'Champion');
    });

    test('fromJson handles missing optional fields', () {
      final prize = TournamentPrize.fromJson({'place': 2});

      expect(prize.coins, 0);
      expect(prize.gems, 0);
      expect(prize.skinId, isNull);
    });

    test('placeLabel formats correctly', () {
      expect(const TournamentPrize(place: 1).placeLabel, '1st Place');
      expect(const TournamentPrize(place: 2).placeLabel, '2nd Place');
      expect(const TournamentPrize(place: 3).placeLabel, '3rd Place');
      expect(const TournamentPrize(place: 4).placeLabel, '4th Place');
    });

    test('toJson round-trips correctly', () {
      const prize = TournamentPrize(
        place: 1,
        coins: 500,
        gems: 25,
        skinId: 'gold',
      );
      final json = prize.toJson();
      final parsed = TournamentPrize.fromJson(json);

      expect(parsed, prize);
    });
  });

  group('Tournament', () {
    final now = DateTime.now();
    final sampleJson = {
      'id': 'abc-123',
      'name': 'Weekly Chess',
      'description': 'A weekly chess tournament',
      'game_type': 'chess',
      'format': 'single_elimination',
      'organizer_id': 'user-1',
      'is_official': true,
      'registration_start': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'registration_end': now.add(const Duration(hours: 1)).toIso8601String(),
      'start_time': now.add(const Duration(hours: 2)).toIso8601String(),
      'min_participants': 8,
      'max_participants': 32,
      'current_participants': 12,
      'entry_fee_coins': 100,
      'entry_fee_gems': 0,
      'prize_pool': [
        {'place': 1, 'coins': 1000, 'gems': 50},
        {'place': 2, 'coins': 500},
      ],
      'settings': {'time_control': '10+5'},
      'status': 'registration',
      'min_subscription_tier': 'free',
      'room_social_mode': 'focus',
      'created_at': now.toIso8601String(),
    };

    test('fromJson parses correctly', () {
      final t = Tournament.fromJson(sampleJson);

      expect(t.id, 'abc-123');
      expect(t.name, 'Weekly Chess');
      expect(t.gameType, 'chess');
      expect(t.format, TournamentFormat.singleElimination);
      expect(t.isOfficial, true);
      expect(t.currentParticipants, 12);
      expect(t.maxParticipants, 32);
      expect(t.entryFeeCoins, 100);
      expect(t.prizes.length, 2);
      expect(t.prizes[0].coins, 1000);
      expect(t.status, TournamentStatus.registration);
      expect(t.roomSocialMode, 'focus');
    });

    test('isFree returns correctly', () {
      final free = Tournament.fromJson({
        ...sampleJson,
        'entry_fee_coins': 0,
        'entry_fee_gems': 0,
      });
      expect(free.isFree, true);

      final paid = Tournament.fromJson(sampleJson);
      expect(paid.isFree, false);
    });

    test('isFull returns correctly', () {
      final full = Tournament.fromJson({
        ...sampleJson,
        'current_participants': 32,
        'max_participants': 32,
      });
      expect(full.isFull, true);

      final notFull = Tournament.fromJson(sampleJson);
      expect(notFull.isFull, false);
    });

    test('isRegistrationOpen checks status and capacity', () {
      final open = Tournament.fromJson(sampleJson);
      expect(open.isRegistrationOpen, true);

      final full = Tournament.fromJson({
        ...sampleJson,
        'current_participants': 32,
      });
      expect(full.isRegistrationOpen, false);

      final started = Tournament.fromJson({
        ...sampleJson,
        'status': 'in_progress',
      });
      expect(started.isRegistrationOpen, false);
    });

    test('isLive and isCompleted', () {
      final live = Tournament.fromJson({
        ...sampleJson,
        'status': 'in_progress',
      });
      expect(live.isLive, true);
      expect(live.isCompleted, false);

      final completed = Tournament.fromJson({
        ...sampleJson,
        'status': 'completed',
      });
      expect(completed.isCompleted, true);
      expect(completed.isLive, false);
    });

    test('equatable uses id', () {
      final t1 = Tournament.fromJson(sampleJson);
      final t2 = Tournament.fromJson({...sampleJson, 'name': 'Changed'});
      expect(t1, t2); // Same id
    });
  });

  group('TournamentMatch', () {
    test('fromJson parses correctly', () {
      final match = TournamentMatch.fromJson({
        'id': 'm1',
        'tournament_id': 't1',
        'round': 1,
        'match_number': 1,
        'bracket_side': 'winners',
        'player1_id': 'p1',
        'player2_id': 'p2',
        'player1': {'username': 'Alice', 'avatar_url': null},
        'player2': {'username': 'Bob', 'avatar_url': null},
        'player1_seed': 1,
        'player2_seed': 4,
        'winner_id': 'p1',
        'player1_score': 3,
        'player2_score': 1,
        'status': 'completed',
      });

      expect(match.player1Name, 'Alice');
      expect(match.player2Name, 'Bob');
      expect(match.winnerId, 'p1');
      expect(match.isCompleted, true);
      expect(match.bracketSide, BracketSide.winners);
    });

    test('isBye, isReady, isLive', () {
      final bye = TournamentMatch.fromJson({
        'id': 'm1',
        'tournament_id': 't1',
        'round': 1,
        'match_number': 1,
        'bracket_side': 'winners',
        'status': 'bye',
      });
      expect(bye.isBye, true);

      final ready = TournamentMatch.fromJson({
        'id': 'm2',
        'tournament_id': 't1',
        'round': 1,
        'match_number': 2,
        'bracket_side': 'winners',
        'player1_id': 'p1',
        'player2_id': 'p2',
        'status': 'ready',
      });
      expect(ready.isReady, true);

      final live = TournamentMatch.fromJson({
        'id': 'm3',
        'tournament_id': 't1',
        'round': 1,
        'match_number': 3,
        'bracket_side': 'winners',
        'status': 'in_progress',
      });
      expect(live.isLive, true);
    });
  });

  group('TournamentParticipant', () {
    test('fromJson with nested profile', () {
      final p = TournamentParticipant.fromJson({
        'id': 'tp1',
        'tournament_id': 't1',
        'user_id': 'u1',
        'profile': {'username': 'Alice', 'avatar_url': 'http://img.png'},
        'status': 'active',
        'seed': 3,
        'wins': 2,
        'losses': 1,
        'points': 6,
        'registered_at': DateTime.now().toIso8601String(),
      });

      expect(p.username, 'Alice');
      expect(p.avatarUrl, 'http://img.png');
      expect(p.status, ParticipantStatus.active);
      expect(p.seed, 3);
      expect(p.wins, 2);
    });
  });

  group('TournamentChatMessage', () {
    test('fromJson parses correctly', () {
      final msg = TournamentChatMessage.fromJson({
        'id': 'c1',
        'tournament_id': 't1',
        'sender_id': 'u1',
        'sender': {'username': 'Alice', 'avatar_url': null},
        'content': 'Good luck!',
        'is_announcement': false,
        'created_at': '2026-03-08T12:00:00Z',
      });

      expect(msg.senderName, 'Alice');
      expect(msg.content, 'Good luck!');
      expect(msg.isAnnouncement, false);
    });
  });

  group('TournamentRegistrationResult', () {
    test('has all expected values', () {
      // 12 = the original 8 + team results (teamRequired/teamFull/
      // teamNotFound, 2v2 feature) + registeredRequired (#188). This test
      // had been stale at 8 since the team feature landed.
      expect(TournamentRegistrationResult.values.length, 12);
      expect(TournamentRegistrationResult.values,
          contains(TournamentRegistrationResult.success));
      expect(TournamentRegistrationResult.values,
          contains(TournamentRegistrationResult.insufficientFunds));
      expect(TournamentRegistrationResult.values,
          contains(TournamentRegistrationResult.registeredRequired));
    });
  });
}
