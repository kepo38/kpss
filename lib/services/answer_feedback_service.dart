import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pomodoro_service.dart';

/// Doğru / yanlış cevap için ses + titreşim.
class AnswerFeedbackService {
  AnswerFeedbackService._();
  static final AnswerFeedbackService instance = AnswerFeedbackService._();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _testCompletePlayer = AudioPlayer();
  bool _ready = false;
  bool _testCompleteReady = false;

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
        ),
      ),
    );
    await _player.setReleaseMode(ReleaseMode.stop);
    _ready = true;
  }

  Future<void> _ensureTestCompleteReady() async {
    if (_testCompleteReady) return;
    await _testCompletePlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await _testCompletePlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _testCompletePlayer.setReleaseMode(ReleaseMode.stop);
    _testCompleteReady = true;
  }

  Future<void> playCorrect() async {
    await ensureReady();
    HapticFeedback.lightImpact();
    await _playAsset(
      _player,
      'sounds/correct.wav',
      onFailure: () => SystemSound.play(SystemSoundType.click),
    );
  }

  Future<void> playWrong() async {
    await ensureReady();
    HapticFeedback.mediumImpact();
    await _playAsset(
      _player,
      'sounds/wrong.wav',
      onFailure: () => SystemSound.play(SystemSoundType.alert),
    );
  }

  /// TG denemede son 10 dakikaya girildiğinde tek seferlik uyarı.
  Future<void> playExamTimeWarning() async {
    await ensureReady();
    HapticFeedback.heavyImpact();
    await _playAsset(
      _player,
      'sounds/focus_complete.wav',
      onFailure: () => SystemSound.play(SystemSoundType.alert),
    );
  }

  /// Test bitince sonuç ekranı — kısa tamamlanma efekti (~2,5 sn).
  Future<void> playTestComplete() async {
    _testCompleteReady = false;
    await _ensureTestCompleteReady();
    await PomodoroService.instance.pauseForFeedback();
    HapticFeedback.mediumImpact();
    try {
      await _playAsset(
        _testCompletePlayer,
        'sounds/test_complete.wav',
        onFailure: () => SystemSound.play(SystemSoundType.click),
        waitForCompletion: true,
        completionTimeout: const Duration(seconds: 5),
      );
    } finally {
      await PomodoroService.instance.resumeAfterFeedback();
    }
  }

  Future<void> _playAsset(
    AudioPlayer player,
    String asset, {
    required void Function() onFailure,
    bool waitForCompletion = false,
    Duration completionTimeout = const Duration(seconds: 4),
  }) async {
    StreamSubscription<void>? sub;
    try {
      await player.stop();
      if (waitForCompletion) {
        final completer = Completer<void>();
        sub = player.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await player.setVolume(1.0);
        await player.play(AssetSource(asset));
        await completer.future.timeout(
          completionTimeout,
          onTimeout: () {},
        );
      } else {
        await player.play(AssetSource(asset));
        await player.onPlayerComplete.first.timeout(
          completionTimeout,
          onTimeout: () {},
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AnswerFeedbackService asset failed ($asset): $e\n$st');
      }
      onFailure();
    } finally {
      await sub?.cancel();
      if (player == _player) {
        await _restorePomodoroMusic();
      }
    }
  }

  /// Cevap sesi odak çalmış olabilir — Pomodoro ortam / Deep Work devam etsin.
  Future<void> _restorePomodoroMusic() async {
    await PomodoroService.instance.ensureDeepWorkKeepsPlaying();
    await PomodoroService.instance.ensureAmbientKeepsPlaying();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _testCompletePlayer.dispose();
    _ready = false;
    _testCompleteReady = false;
  }
}
