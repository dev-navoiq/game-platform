import 'package:test/test.dart';
import 'package:social_core/social_core.dart';

void main() {
  group('MuteCalculator.shouldMute', () {
    test('returns false when playerCount is 0', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 1, playerCount: 0),
        isFalse,
      );
    });

    test('returns false when playerCount is negative', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 1, playerCount: -1),
        isFalse,
      );
    });

    test('returns true when 2 of 4 players vote (50%)', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 2, playerCount: 4),
        isTrue,
      );
    });

    test('returns true when 3 of 4 players vote (75%)', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 3, playerCount: 4),
        isTrue,
      );
    });

    test('returns false when 1 of 4 players vote (25%)', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 1, playerCount: 4),
        isFalse,
      );
    });

    test('returns true when 2 of 3 players vote (ceil(1.5) = 2)', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 2, playerCount: 3),
        isTrue,
      );
    });

    test('returns false when 1 of 3 players vote', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 1, playerCount: 3),
        isFalse,
      );
    });

    test('returns true when 3 of 5 players vote (ceil(2.5) = 3)', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 3, playerCount: 5),
        isTrue,
      );
    });

    test('returns true when 1 of 1 player votes', () {
      expect(
        MuteCalculator.shouldMute(voteCount: 1, playerCount: 1),
        isTrue,
      );
    });
  });

  group('MuteCalculator.votesNeeded', () {
    test('returns 2 when 0 of 4 have voted', () {
      expect(
        MuteCalculator.votesNeeded(currentVotes: 0, playerCount: 4),
        equals(2),
      );
    });

    test('returns 1 when 1 of 4 have voted', () {
      expect(
        MuteCalculator.votesNeeded(currentVotes: 1, playerCount: 4),
        equals(1),
      );
    });

    test('returns 0 when threshold is already met', () {
      expect(
        MuteCalculator.votesNeeded(currentVotes: 3, playerCount: 4),
        equals(0),
      );
    });

    test('returns 0 when votes exceed threshold', () {
      expect(
        MuteCalculator.votesNeeded(currentVotes: 4, playerCount: 4),
        equals(0),
      );
    });

    test('returns 0 for 0 players', () {
      expect(
        MuteCalculator.votesNeeded(currentVotes: 0, playerCount: 0),
        equals(0),
      );
    });

    test('handles odd player counts correctly', () {
      // 5 players, need ceil(2.5) = 3 votes
      expect(
        MuteCalculator.votesNeeded(currentVotes: 1, playerCount: 5),
        equals(2),
      );
    });
  });

  group('MuteCalculator.votesRequired', () {
    test('returns 0 for 0 players', () {
      expect(MuteCalculator.votesRequired(0), equals(0));
    });

    test('returns 1 for 1 player', () {
      expect(MuteCalculator.votesRequired(1), equals(1));
    });

    test('returns 2 for 4 players', () {
      expect(MuteCalculator.votesRequired(4), equals(2));
    });

    test('returns 3 for 5 players', () {
      expect(MuteCalculator.votesRequired(5), equals(3));
    });

    test('returns 4 for 7 players', () {
      expect(MuteCalculator.votesRequired(7), equals(4));
    });
  });
}
