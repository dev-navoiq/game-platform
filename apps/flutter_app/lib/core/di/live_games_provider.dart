import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feature_flag_providers.dart';

/// #285: single-game launch gate (#272 decision). A game is live when its
/// `game_live_<type>` feature flag is enabled; Oh Hell is the hardcoded
/// floor so a failed flag fetch can never lock the flagship. Everything
/// else fails closed: no flag row → Coming soon. Staging seeds all eight
/// flags on (nothing changes there); production seeds none until a game is
/// ready — flipping one live is a config edit, no app release.
const kAlwaysLiveGame = 'oh_hell';

final isGameLiveProvider = Provider.family<bool, String>((ref, gameType) {
  if (gameType == kAlwaysLiveGame) return true;
  return ref.watch(isFeatureEnabledProvider('game_live_$gameType'));
});
