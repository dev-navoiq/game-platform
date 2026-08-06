// #237 — newRound dispatch retry.
//
// A single dropped validate-move request at roundEnd used to strand the
// table forever: the ready ticker was already cancelled and nothing ever
// re-sent the move. dispatchNewRoundWithRetry retries with backoff, stops
// early once the round has advanced, and swallows total failure (the
// manual Next Round button remains the last resort).

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/game/services/round_advance_guard.dart';

void main() {
  const fast = Duration(milliseconds: 1);

  group('dispatchNewRoundWithRetry', () {
    test('single success sends exactly once', () async {
      var calls = 0;
      await RoundAdvanceGuard.dispatchNewRoundWithRetry(
        send: () async => calls++,
        baseDelay: fast,
      );
      expect(calls, 1);
    });

    test('transient failures are retried until success', () async {
      var calls = 0;
      await RoundAdvanceGuard.dispatchNewRoundWithRetry(
        send: () async {
          calls++;
          if (calls < 3) throw Exception('Failed to fetch');
        },
        baseDelay: fast,
      );
      expect(calls, 3, reason: 'two failures then the success');
    });

    test('stops early when the round has already advanced', () async {
      var calls = 0;
      await RoundAdvanceGuard.dispatchNewRoundWithRetry(
        send: () async {
          calls++;
          throw Exception('Failed to fetch');
        },
        stillNeeded: () => false, // state moved on after the first failure
        baseDelay: fast,
      );
      expect(calls, 1, reason: 'no retry once the advance is moot');
    });

    test('exhausted retries are swallowed, not rethrown', () async {
      var calls = 0;
      await expectLater(
        RoundAdvanceGuard.dispatchNewRoundWithRetry(
          send: () async {
            calls++;
            throw Exception('Failed to fetch');
          },
          attempts: 4,
          baseDelay: fast,
        ),
        completes,
      );
      expect(calls, 4);
    });
  });
}
