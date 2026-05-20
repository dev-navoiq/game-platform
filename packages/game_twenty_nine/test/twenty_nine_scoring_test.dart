import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_twenty_nine/game_twenty_nine.dart';

void main() {
  group('TwentyNine Scoring', () {
    group('Card points', () {
      test('all point-scoring cards', () {
        // 4 suits × (J=3, 9=2, A=1, 10=1) = 4 × 7 = 28
        final scoringCards = {
          Rank.jack: 3,
          Rank.nine: 2,
          Rank.ace: 1,
          Rank.ten: 1,
        };

        for (final suit in Suit.values) {
          for (final entry in scoringCards.entries) {
            final card = PlayingCard(suit, entry.key);
            expect(
              TwentyNineConfig.getCardPoints(card),
              entry.value,
              reason: '$card should score ${entry.value}',
            );
          }
        }
      });

      test('zero-value cards score nothing', () {
        final zeroRanks = [Rank.king, Rank.queen, Rank.eight, Rank.seven];
        for (final suit in Suit.values) {
          for (final rank in zeroRanks) {
            final card = PlayingCard(suit, rank);
            expect(
              TwentyNineConfig.getCardPoints(card),
              0,
              reason: '$card should score 0',
            );
          }
        }
      });

      test('total deck points equal 28', () {
        final deck = Deck.standard32();
        var total = 0;
        while (deck.remaining > 0) {
          total += TwentyNineConfig.getCardPoints(deck.draw()!);
        }
        expect(total, 28);
      });
    });

    group('Round scoring', () {
      test('bidding team wins round when they meet or exceed bid', () {
        final scorer = TwentyNineScorer();
        final result = scorer.scoreRound(
          bid: 16,
          biddingTeam: 0,
          teamPoints: {0: 17, 1: 11},
          gameScores: {0: 0, 1: 0},
        );
        expect(result.biddingTeamScored, isTrue);
        // Winning team gains 1 game-point
        expect(result.updatedGameScores[0], 1);
        expect(result.updatedGameScores[1], 0);
      });

      test('bidding team loses round when below bid', () {
        final scorer = TwentyNineScorer();
        final result = scorer.scoreRound(
          bid: 20,
          biddingTeam: 0,
          teamPoints: {0: 14, 1: 14},
          gameScores: {0: 2, 1: 1},
        );
        expect(result.biddingTeamScored, isFalse);
        // Defending team gains 1 game-point on a normal failed bid
        expect(result.updatedGameScores[1], greaterThan(1));
      });

      test('29 bid win gives maximum game-points', () {
        final scorer = TwentyNineScorer();
        final result = scorer.scoreRound(
          bid: 29,
          biddingTeam: 0,
          teamPoints: {0: 28, 1: 0},
          gameScores: {0: 0, 1: 0},
        );
        // Winning a 29 bid is worth more than 1 game-point
        expect(result.updatedGameScores[0], greaterThan(1));
      });
    });

    group('Card strength ordering (J > 9 > A > 10 > K > Q > 8 > 7)', () {
      final strengthOrder = [
        Rank.jack,
        Rank.nine,
        Rank.ace,
        Rank.ten,
        Rank.king,
        Rank.queen,
        Rank.eight,
        Rank.seven,
      ];

      test('each card is stronger than the one after it', () {
        for (var i = 0; i < strengthOrder.length - 1; i++) {
          final stronger = PlayingCard(Suit.hearts, strengthOrder[i]);
          final weaker = PlayingCard(Suit.hearts, strengthOrder[i + 1]);
          expect(
            TwentyNineConfig.cardStrength(stronger),
            greaterThan(TwentyNineConfig.cardStrength(weaker)),
            reason: '${stronger.rank} should beat ${weaker.rank}',
          );
        }
      });
    });
  });
}
