import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService.instance;
});

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  AudioPlayer? _effectsPlayer;
  AudioPlayer? _musicPlayer;

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  Future<void> initialize() async {
    if (kIsWeb) return; // Audio plugins not available on web
    try {
      _effectsPlayer = AudioPlayer();
      _musicPlayer = AudioPlayer();
      await _effectsPlayer!.setReleaseMode(ReleaseMode.stop);
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('AudioService: failed to initialize — $e');
    }
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      _musicPlayer?.stop();
    }
  }

  Future<void> playCardDeal() => _playEffect('audio/card_deal.mp3');
  Future<void> playCardPlay() => _playEffect('audio/card_play.mp3');
  Future<void> playTrickWin() => _playEffect('audio/trick_win.mp3');
  Future<void> playGameWin() => _playEffect('audio/game_win.mp3');
  Future<void> playGameLose() => _playEffect('audio/game_lose.mp3');
  Future<void> playButtonClick() => _playEffect('audio/button_click.mp3');
  Future<void> playNotification() => _playEffect('audio/notification.mp3');

  Future<void> _playEffect(String path) async {
    if (!_soundEnabled || _effectsPlayer == null) return;
    try {
      await _effectsPlayer!.play(AssetSource(path));
    } catch (e) {
      debugPrint('AudioService: playEffect failed — $e');
    }
  }

  Future<void> playBackgroundMusic(String path) async {
    if (!_musicEnabled || _musicPlayer == null) return;
    try {
      await _musicPlayer!.play(AssetSource(path));
      await _musicPlayer!.setVolume(0.3);
    } catch (e) {
      debugPrint('AudioService: playMusic failed — $e');
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer?.stop();
  }

  void dispose() {
    _effectsPlayer?.dispose();
    _musicPlayer?.dispose();
  }
}
