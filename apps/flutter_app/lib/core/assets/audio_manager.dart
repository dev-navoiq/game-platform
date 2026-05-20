import '../services/audio_service.dart';
import 'audio_assets.dart';

/// Manages audio asset preloading and provides a typed interface
/// for playing game sounds through [AudioService].
class AudioManager {
  final AudioService _audioService;

  AudioManager(this._audioService);

  /// Preload common sounds used across all games.
  Future<void> preloadCommon() async {
    // AudioService currently handles playback on demand via AssetSource.
    // This method is a hook for future preloading optimisation.
    await _audioService.initialize();
  }

  /// Preload game-specific sounds.
  Future<void> preloadForGame(String gameType) async {
    // Reserved for future use — sounds are currently loaded on demand.
    // ignore: unused_local_variable
    final paths = AudioAssets.forGame(gameType);
  }

  // ── Card game sounds ──────────────────────────────────────────────────

  Future<void> playCardDeal() => _audioService.playCardDeal();
  Future<void> playCardPlay() => _audioService.playCardPlay();
  Future<void> playTrickWin() => _audioService.playTrickWin();
  Future<void> playGameWin() => _audioService.playGameWin();
  Future<void> playGameLose() => _audioService.playGameLose();

  // ── UI sounds ─────────────────────────────────────────────────────────

  Future<void> playButtonClick() => _audioService.playButtonClick();
  Future<void> playNotification() => _audioService.playNotification();

  // ── Music ─────────────────────────────────────────────────────────────

  Future<void> playLobbyMusic() =>
      _audioService.playBackgroundMusic(AudioAssets.musicLobby);

  Future<void> playGameplayMusic() =>
      _audioService.playBackgroundMusic(AudioAssets.musicGameplay);

  Future<void> stopMusic() => _audioService.stopMusic();
}
