import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Doğru / yanlış cevap için ses + titreşim.
class AnswerFeedbackService {
  AnswerFeedbackService._();
  static final AnswerFeedbackService instance = AnswerFeedbackService._();

  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    _ready = true;
  }

  Future<void> playCorrect() async {
    await ensureReady();
    HapticFeedback.lightImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/correct.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> playWrong() async {
    await ensureReady();
    HapticFeedback.mediumImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/wrong.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  /// TG denemede son 10 dakikaya girildiğinde tek seferlik uyarı.
  Future<void> playExamTimeWarning() async {
    await ensureReady();
    HapticFeedback.heavyImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/focus_complete.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    _ready = false;
  }
}
