import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/pomodoro_session_model.dart';

class PomodoroService {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  static const deepWorkAssetPath = 'sounds/deep_work_music.mp3';

  final List<PomodoroSessionModel> _gecmis = [];
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _deepWorkPlayer = AudioPlayer();
  final AudioPlayer _chimePlayer = AudioPlayer();

  AmbientSound _selectedSound = AmbientSound.sessiz;
  bool _audioReady = false;
  bool _deepWorkAudioReady = false;
  bool _ambientPlaying = false;
  bool _deepWorkPlaying = false;
  double _ambientVolume = 0.42;
  bool _wakeLockHeld = false;

  List<PomodoroSessionModel> get gecmis => List.unmodifiable(_gecmis);
  AmbientSound get selectedSound => _selectedSound;
  bool get ambientPlaying => _ambientPlaying;
  bool get deepWorkPlaying => _deepWorkPlaying;
  double get ambientVolume => _ambientVolume;

  int get bugunToplamDakika {
    final today = DateTime.now();
    return _gecmis
        .where((s) =>
            s.tamamlandi &&
            s.baslangic.year == today.year &&
            s.baslangic.month == today.month &&
            s.baslangic.day == today.day)
        .fold(0, (sum, s) => sum + s.sureDakika);
  }

  void completeSession(PomodoroSessionModel session) {
    _gecmis.add(session);
  }

  Future<void> setAmbientVolume(double volume) async {
    _ambientVolume = volume.clamp(0.0, 1.0);
    if (_ambientPlaying) {
      await _ambientPlayer.setVolume(_ambientVolume);
    }
  }

  /// Ortam sesi seç — sessiz değilse hemen önizleme çalar.
  Future<void> setSelectedSound(AmbientSound sound) async {
    _selectedSound = sound;
    if (sound == AmbientSound.sessiz) {
      await stopAmbient();
    } else {
      await stopDeepWork();
      await playAmbient();
    }
  }

  /// Ekran kilitliyken ses/zamanlayıcı için CPU uyanık kalsın.
  Future<void> setSessionActive(bool active) async {
    try {
      if (active && !_wakeLockHeld) {
        await WakelockPlus.enable();
        _wakeLockHeld = true;
      } else if (!active && _wakeLockHeld) {
        await WakelockPlus.disable();
        _wakeLockHeld = false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Wakelock: $e');
    }
  }

  Future<void> _ensureAmbientAudio() async {
    if (_audioReady) return;
    await _ambientPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
          stayAwake: true,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ),
    );
    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    await _ambientPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _audioReady = true;
  }

  Future<void> playAmbient() async {
    final path = _selectedSound.assetPath;
    if (path == null) {
      await stopAmbient();
      return;
    }
    try {
      await stopDeepWork();
      await _ensureAmbientAudio();
      await _ambientPlayer.stop();
      await _ambientPlayer.setVolume(0);
      await _ambientPlayer.play(AssetSource(path));
      _ambientPlaying = true;
      const steps = 8;
      for (var i = 1; i <= steps; i++) {
        if (!_ambientPlaying) return;
        await _ambientPlayer.setVolume(_ambientVolume * i / steps);
        await Future<void>.delayed(const Duration(milliseconds: 45));
      }
    } catch (e, st) {
      _ambientPlaying = false;
      if (kDebugMode) {
        debugPrint('Ortam sesi çalınamadı ($path): $e\n$st');
      }
    }
  }

  Future<void> stopAmbient() async {
    try {
      if (_ambientPlaying) {
        final v = _ambientVolume;
        for (var i = 4; i >= 0; i--) {
          await _ambientPlayer.setVolume(v * i / 4);
          await Future<void>.delayed(const Duration(milliseconds: 35));
        }
      }
      await _ambientPlayer.stop();
    } catch (_) {}
    _ambientPlaying = false;
  }

  Future<void> _ensureDeepWorkAudio() async {
    if (_deepWorkAudioReady) return;
    await _deepWorkPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
          stayAwake: true,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ),
    );
    await _deepWorkPlayer.setReleaseMode(ReleaseMode.loop);
    await _deepWorkPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    _deepWorkAudioReady = true;
  }

  /// Deep Work müziği — uygulama asset'inden loop. Ortam sesini durdurur.
  Future<void> playDeepWork() async {
    try {
      await stopAmbient();
      _selectedSound = AmbientSound.sessiz;
      await _ensureDeepWorkAudio();
      await _deepWorkPlayer.stop();
      await _deepWorkPlayer.setVolume(0.72);
      await _deepWorkPlayer.play(AssetSource(deepWorkAssetPath));
      _deepWorkPlaying = true;
    } catch (e, st) {
      _deepWorkPlaying = false;
      if (kDebugMode) {
        debugPrint('Deep Work çalınamadı: $e\n$st');
      }
      rethrow;
    }
  }

  Future<void> stopDeepWork() async {
    try {
      await _deepWorkPlayer.stop();
    } catch (_) {}
    _deepWorkPlaying = false;
  }

  Future<void> toggleDeepWork() async {
    if (_deepWorkPlaying) {
      await stopDeepWork();
    } else {
      await playDeepWork();
    }
  }

  /// Süre bitiş zili (kısa, loop değil).
  Future<void> playCompletionChime() async {
    try {
      await _chimePlayer.stop();
      await _chimePlayer.setReleaseMode(ReleaseMode.stop);
      await _chimePlayer.setVolume(0.75);
      await _chimePlayer.play(AssetSource('sounds/focus_complete.wav'));
    } catch (e) {
      if (kDebugMode) debugPrint('Bitiş zili: $e');
    }
  }

  Future<void> dispose() async {
    await setSessionActive(false);
    await stopAmbient();
    await stopDeepWork();
    await _ambientPlayer.dispose();
    await _deepWorkPlayer.dispose();
    await _chimePlayer.dispose();
    _audioReady = false;
    _deepWorkAudioReady = false;
  }
}
