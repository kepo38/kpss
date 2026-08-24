import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'pomodoro_service.dart';

/// Doğru / yanlış cevap için ses + titreşim.
class AnswerFeedbackService {
  AnswerFeedbackService._();
  static final AnswerFeedbackService instance = AnswerFeedbackService._();

  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.stop);
    _ready = true;
  }

  Future<void> playCorrect() async {
    await ensureReady();
    HapticFeedback.lightImpact();
    await _playAsset(
      'sounds/correct.wav',
      onFailure: () => SystemSound.play(SystemSoundType.click),
    );
  }

  Future<void> playWrong() async {
    await ensureReady();
    HapticFeedback.mediumImpact();
    await _playAsset(
      'sounds/wrong.wav',
      onFailure: () => SystemSound.play(SystemSoundType.alert),
    );
  }

  /// TG denemede son 10 dakikaya girildiğinde tek seferlik uyarı.
  Future<void> playExamTimeWarning() async {
    await ensureReady();
    HapticFeedback.heavyImpact();
    await _playAsset(
      'sounds/focus_complete.wav',
      onFailure: () => SystemSound.play(SystemSoundType.alert),
    );
  }

  /// Test bitince sonuç ekranı — kısa tamamlanma efekti (~2,5 sn).
  Future<void> playTestComplete() async {
    // Reklam / başka oynatıcı ses odağını bozmuş olabilir — bağlamı yenile.
    _ready = false;
    await ensureReady();
    HapticFeedback.mediumImpact();
    await _playAsset(
      'sounds/test_complete.wav',
      onFailure: () => SystemSound.play(SystemSoundType.click),
    );
  }

  Future<void> _playAsset(
    String asset, {
    required void Function() onFailure,
  }) async {
    try {
      await _player.stop();
      final done = _player.onPlayerComplete.first;
      await _player.play(AssetSource(asset));
      await done.timeout(const Duration(seconds: 4), onTimeout: () {});
    } catch (_) {
      onFailure();
    } finally {
      await _restorePomodoroMusic();
    }
  }

  /// Cevap sesi odak çalmış olabilir — Pomodoro ortam / Deep Work devam etsin.
  Future<void> _restorePomodoroMusic() async {
    await PomodoroService.instance.ensureDeepWorkKeepsPlaying();
    await PomodoroService.instance.ensureAmbientKeepsPlaying();
  }

  Future<void> dispose() async {
    await _player.dispose();
    _ready = false;
  }
}
