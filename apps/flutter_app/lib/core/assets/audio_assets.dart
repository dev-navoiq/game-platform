/// Static const path definitions for all audio assets.
///
/// Organized by category, matching the `assets/audio/` directory structure.
/// Actual audio files are added later — these constants define the contract.
class AudioAssets {
  AudioAssets._();

  // ── Common ──────────────────────────────────────────────────────────────

  static const String buttonClick = 'audio/common/button_click.mp3';
  static const String notification = 'audio/common/notification.mp3';
  static const String coinEarned = 'audio/common/coin_earned.mp3';
  static const String levelUp = 'audio/common/level_up.mp3';
  static const String error = 'audio/common/error.mp3';
  static const String countdown = 'audio/common/countdown.mp3';
  static const String timerWarning = 'audio/common/timer_warning.mp3';

  // ── Card games (shared) ────────────────────────────────────────────────

  static const String cardDeal = 'audio/common/card_deal.mp3';
  static const String cardPlay = 'audio/common/card_play.mp3';
  static const String cardShuffle = 'audio/common/card_shuffle.mp3';
  static const String trickWin = 'audio/common/trick_win.mp3';
  static const String gameWin = 'audio/common/game_win.mp3';
  static const String gameLose = 'audio/common/game_lose.mp3';
  static const String bidPlace = 'audio/common/bid_place.mp3';
  static const String turnAlert = 'audio/common/turn_alert.mp3';

  // ── Twenty-Nine ────────────────────────────────────────────────────────

  static const String twentyNineTrumpReveal =
      'audio/twenty_nine/trump_reveal.mp3';
  static const String twentyNineBidWin = 'audio/twenty_nine/bid_win.mp3';

  // ── Oh Hell ────────────────────────────────────────────────────────────

  static const String ohHellBidForbidden =
      'audio/oh_hell/bid_forbidden.mp3';
  static const String ohHellExactBid = 'audio/oh_hell/exact_bid.mp3';

  // ── Hearts ─────────────────────────────────────────────────────────────

  static const String heartsBroken = 'audio/hearts/hearts_broken.mp3';
  static const String heartsMoonShot = 'audio/hearts/moon_shot.mp3';

  // ── Chess ──────────────────────────────────────────────────────────────

  static const String chessPieceMove = 'audio/chess/piece_move.mp3';
  static const String chessCapture = 'audio/chess/capture.mp3';
  static const String chessCheck = 'audio/chess/check.mp3';
  static const String chessCheckmate = 'audio/chess/checkmate.mp3';
  static const String chessCastle = 'audio/chess/castle.mp3';
  static const String chessPromotion = 'audio/chess/promotion.mp3';
  static const String chessDraw = 'audio/chess/draw.mp3';

  // ── Ludo ───────────────────────────────────────────────────────────────

  static const String ludoDiceRoll = 'audio/ludo/dice_roll.mp3';
  static const String ludoTokenMove = 'audio/ludo/token_move.mp3';
  static const String ludoCapture = 'audio/ludo/capture.mp3';
  static const String ludoTokenFinish = 'audio/ludo/token_finish.mp3';
  static const String ludoSixRolled = 'audio/ludo/six_rolled.mp3';

  // ── Sequence ───────────────────────────────────────────────────────────

  static const String sequenceChipPlace = 'audio/sequence/chip_place.mp3';
  static const String sequenceChipRemove =
      'audio/sequence/chip_remove.mp3';
  static const String sequenceComplete = 'audio/sequence/sequence_complete.mp3';

  // ── Music ──────────────────────────────────────────────────────────────

  static const String musicLobby = 'audio/common/music_lobby.mp3';
  static const String musicGameplay = 'audio/common/music_gameplay.mp3';

  /// All common sound paths for preloading.
  static const List<String> commonSounds = [
    buttonClick,
    notification,
    cardDeal,
    cardPlay,
    cardShuffle,
    trickWin,
    gameWin,
    gameLose,
  ];

  /// Returns game-specific sound paths for preloading.
  static List<String> forGame(String gameType) {
    switch (gameType) {
      case 'twenty_nine':
        return [twentyNineTrumpReveal, twentyNineBidWin];
      case 'oh_hell':
        return [ohHellBidForbidden, ohHellExactBid];
      case 'hearts':
        return [heartsBroken, heartsMoonShot];
      case 'chess':
        return [chessPieceMove, chessCapture, chessCheck, chessCheckmate];
      case 'ludo':
        return [ludoDiceRoll, ludoTokenMove, ludoCapture, ludoTokenFinish];
      case 'sequence':
        return [sequenceChipPlace, sequenceChipRemove, sequenceComplete];
      default:
        return [];
    }
  }
}
