import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/pomodoro_session_model.dart';
import 'gamification_service.dart';
import 'notification_service.dart';

typedef PomodoroSessionCompleteCallback = void Function({
  required bool endingBreak,
  required String title,
  required String body,
});

/// Odak zamanlayıcısı + Deep Work müziği — ekran kapansa da devam eder.
class PomodoroService extends ChangeNotifier {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  static const deepWorkAssetPath = 'sounds/deep_work_music.mp3';
  static const breakSeconds = 5 * 60;

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

  PomodoroPreset _preset = PomodoroPreset.dk20;
  int _remainingSeconds = 20 * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  DateTime? _sessionEndAt;
  Timer? _timer;
  StreamSubscription<void>? _deepWorkCompleteSub;
  StreamSubscription<PlayerState>? _deepWorkStateSub;
  StreamSubscription<void>? _ambientCompleteSub;
  StreamSubscription<PlayerState>? _ambientStateSub;
  bool _deepWorkUntilSessionEnd = false;
  bool _deepWorkResumeBusy = false;
  bool _ambientUntilStopped = false;
  bool _ambientResumeBusy = false;

  PomodoroSessionCompleteCallback? onSessionCompleteUi;

  List<PomodoroSessionModel> get gecmis => List.unmodifiable(_gecmis);
  AmbientSound get selectedSound => _selectedSound;
  bool get ambientPlaying => _ambientPlaying;
  bool get deepWorkPlaying => _deepWorkPlaying;
  double get ambientVolume => _ambientVolume;

  PomodoroPreset get preset => _preset;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isBreak => _isBreak;

  int get totalSeconds {
    if (_isBreak) return breakSeconds;
    return _preset.dakika * 60;
  }

  double get progress {
    final total = totalSeconds;
    if (total <= 0) return 0;
    return (1.0 - (_remainingSeconds / total)).clamp(0.0, 1.0);
  }

  String get timeLabel {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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

  void setPreset(PomodoroPreset preset) {
    if (_isRunning) return;
    _preset = preset;
    _isBreak = false;
    _remainingSeconds = preset.dakika * 60;
    notifyListeners();
  }

  Future<void> setAmbientVolume(double volume) async {
    _ambientVolume = volume.clamp(0.0, 1.0);
    if (_ambientPlaying) {
      await _ambientPlayer.setVolume(_ambientVolume);
    }
  }

  /// Ortam sesi seç — sessiz değilse hemen çalar (Deep Work gibi döngü).
  Future<void> setSelectedSound(AmbientSound sound) async {
    _selectedSound = sound;
    if (sound == AmbientSound.sessiz) {
      await stopAmbient();
    } else {
      await stopDeepWork();
      await playAmbient();
    }
    notifyListeners();
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

  Future<void> startTimer() async {
    if (_isRunning) return;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = totalSeconds;
    }
    _isRunning = true;
    _sessionEndAt = DateTime.now().add(Duration(seconds: _remainingSeconds));
    await setSessionActive(true);
    await NotificationService.instance.scheduleFocusTimerComplete(
      endsAt: _sessionEndAt!,
      isBreakEnding: _isBreak,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Timer play Deep Work / ortam sesini kesmesin.
    await ensureDeepWorkKeepsPlaying();
    await ensureAmbientKeepsPlaying();
    notifyListeners();
  }

  Future<void> pauseTimer() async {
    _timer?.cancel();
    _timer = null;
    _sessionEndAt = null;
    _isRunning = false;
    await NotificationService.instance.cancelFocusTimerComplete();
    await setSessionActive(false);
    // Pause yalnızca zamanlayıcıyı durdurur — müzik / ortam devam eder.
    await ensureDeepWorkKeepsPlaying();
    await ensureAmbientKeepsPlaying();
    notifyListeners();
  }

  Future<void> resetTimer() async {
    _timer?.cancel();
    _timer = null;
    _sessionEndAt = null;
    _isRunning = false;
    _isBreak = false;
    _remainingSeconds = _preset.dakika * 60;
    await NotificationService.instance.cancelFocusTimerComplete();
    await setSessionActive(false);
    notifyListeners();
  }

  void syncFromLifecycle() {
    if (!_isRunning || _sessionEndAt == null) return;
    final left = _sessionEndAt!.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      unawaited(_onSessionComplete());
    } else if (left != _remainingSeconds) {
      _remainingSeconds = left;
      notifyListeners();
    }
  }

  void _tick() {
    if (_sessionEndAt != null) {
      final left = _sessionEndAt!.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        unawaited(_onSessionComplete());
        return;
      }
      _remainingSeconds = left;
    } else if (_remainingSeconds <= 0) {
      unawaited(_onSessionComplete());
      return;
    } else {
      _remainingSeconds--;
    }
    notifyListeners();
  }

  Future<void> _onSessionComplete() async {
    _timer?.cancel();
    _timer = null;
    _sessionEndAt = null;
    _isRunning = false;
    await setSessionActive(false);
    await NotificationService.instance.cancelFocusTimerComplete();

    final endingBreak = _isBreak;
    final focusMinutes = _preset.dakika;

    if (!_isBreak) {
      completeSession(PomodoroSessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sureDakika: focusMinutes,
        baslangic: DateTime.now().subtract(Duration(seconds: focusMinutes * 60)),
        bitis: DateTime.now(),
        tamamlandi: true,
      ));
      GamificationService.instance.recordStudyMinutes(focusMinutes);
      // Odak turu bitti → Deep Work döngüsünü de kapat.
      await stopDeepWork();
    }

    unawaited(playCompletionChime());
    unawaited(HapticFeedback.heavyImpact());
    unawaited(NotificationService.instance.showFocusTimerComplete(
      isBreakEnding: endingBreak,
    ));

    _isBreak = !_isBreak;
    _remainingSeconds = _isBreak ? breakSeconds : _preset.dakika * 60;
    notifyListeners();

    final title = endingBreak ? 'Mola bitti' : 'Odak tamamlandı';
    final body = endingBreak
        ? 'Yeni bir odak turuna başlayabilirsin.'
        : 'Harika iş. 5 dk mola veya yeni tur.';
    onSessionCompleteUi?.call(
      endingBreak: endingBreak,
      title: title,
      body: body,
    );
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
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    // Deep Work ile aynı: loop + complete yedek.
    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    await _ambientPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _ambientCompleteSub?.cancel();
    _ambientCompleteSub = _ambientPlayer.onPlayerComplete.listen((_) {
      unawaited(_onAmbientTrackComplete());
    });
    await _ambientStateSub?.cancel();
    _ambientStateSub = _ambientPlayer.onPlayerStateChanged.listen((state) {
      if (!_ambientUntilStopped) return;
      if (state == PlayerState.paused || state == PlayerState.stopped) {
        unawaited(ensureAmbientKeepsPlaying());
      }
    });
    _audioReady = true;
  }

  Future<void> _onAmbientTrackComplete() async {
    if (!_ambientUntilStopped) {
      _ambientPlaying = false;
      notifyListeners();
      return;
    }
    await ensureAmbientKeepsPlaying(forceReplay: true);
  }

  /// Bildirim / focus çakışması ortam sesini kesse bile geri getirir.
  Future<void> ensureAmbientKeepsPlaying({bool forceReplay = false}) async {
    if (!_ambientUntilStopped || _ambientResumeBusy) return;
    final path = _selectedSound.assetPath;
    if (path == null) return;
    _ambientResumeBusy = true;
    try {
      await _ensureAmbientAudio();
      final state = _ambientPlayer.state;
      if (forceReplay || state != PlayerState.playing) {
        await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
        await _ambientPlayer.setVolume(_ambientVolume);
        if (state == PlayerState.paused && !forceReplay) {
          await _ambientPlayer.resume();
        } else {
          await _ambientPlayer.play(AssetSource(path));
        }
      }
      _ambientPlaying = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Ortam sesi sürdürülemedi: $e');
    } finally {
      _ambientResumeBusy = false;
    }
  }

  Future<void> playAmbient() async {
    final path = _selectedSound.assetPath;
    if (path == null) {
      await stopAmbient();
      return;
    }
    try {
      await stopDeepWork();
      _ambientUntilStopped = true;
      await _ensureAmbientAudio();
      await _ambientPlayer.stop();
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _ambientPlayer.setVolume(0);
      await _ambientPlayer.play(AssetSource(path));
      _ambientPlaying = true;
      const steps = 8;
      for (var i = 1; i <= steps; i++) {
        if (!_ambientPlaying) return;
        await _ambientPlayer.setVolume(_ambientVolume * i / steps);
        await Future<void>.delayed(const Duration(milliseconds: 45));
      }
      notifyListeners();
    } catch (e, st) {
      _ambientPlaying = false;
      _ambientUntilStopped = false;
      if (kDebugMode) {
        debugPrint('Ortam sesi çalınamadı ($path): $e\n$st');
      }
    }
  }

  Future<void> stopAmbient() async {
    _ambientUntilStopped = false;
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
    notifyListeners();
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
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    // Loop + complete yedek: pomodoro / stop’a kadar kesintisiz.
    await _deepWorkPlayer.setReleaseMode(ReleaseMode.loop);
    await _deepWorkPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _deepWorkCompleteSub?.cancel();
    _deepWorkCompleteSub = _deepWorkPlayer.onPlayerComplete.listen((_) {
      unawaited(_onDeepWorkTrackComplete());
    });
    await _deepWorkStateSub?.cancel();
    _deepWorkStateSub = _deepWorkPlayer.onPlayerStateChanged.listen((state) {
      if (!_deepWorkUntilSessionEnd) return;
      if (state == PlayerState.paused || state == PlayerState.stopped) {
        unawaited(ensureDeepWorkKeepsPlaying());
      }
    });
    _deepWorkAudioReady = true;
  }

  Future<void> _onDeepWorkTrackComplete() async {
    if (!_deepWorkUntilSessionEnd) {
      _deepWorkPlaying = false;
      notifyListeners();
      return;
    }
    await ensureDeepWorkKeepsPlaying(forceReplay: true);
  }

  /// Bildirim / focus çakışması müziği kesse bile geri getirir.
  Future<void> ensureDeepWorkKeepsPlaying({bool forceReplay = false}) async {
    if (!_deepWorkUntilSessionEnd || _deepWorkResumeBusy) return;
    _deepWorkResumeBusy = true;
    try {
      await _ensureDeepWorkAudio();
      final state = _deepWorkPlayer.state;
      if (forceReplay || state != PlayerState.playing) {
        await _deepWorkPlayer.setReleaseMode(ReleaseMode.loop);
        await _deepWorkPlayer.setVolume(0.72);
        if (state == PlayerState.paused && !forceReplay) {
          await _deepWorkPlayer.resume();
        } else {
          await _deepWorkPlayer.play(AssetSource(deepWorkAssetPath));
        }
      }
      _deepWorkPlaying = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Deep Work sürdürülemedi: $e');
    } finally {
      _deepWorkResumeBusy = false;
    }
  }

  /// Deep Work müziği — uygulama asset'inden. Ekran kapansa da çalar.
  Future<void> playDeepWork() async {
    try {
      await stopAmbient();
      _selectedSound = AmbientSound.sessiz;
      _deepWorkUntilSessionEnd = true;
      await _ensureDeepWorkAudio();
      await _deepWorkPlayer.stop();
      await _deepWorkPlayer.setReleaseMode(ReleaseMode.loop);
      await _deepWorkPlayer.setVolume(0.72);
      await _deepWorkPlayer.play(AssetSource(deepWorkAssetPath));
      _deepWorkPlaying = true;
      notifyListeners();
    } catch (e, st) {
      _deepWorkPlaying = false;
      _deepWorkUntilSessionEnd = false;
      if (kDebugMode) {
        debugPrint('Deep Work çalınamadı: $e\n$st');
      }
      rethrow;
    }
  }

  Future<void> stopDeepWork() async {
    _deepWorkUntilSessionEnd = false;
    try {
      await _deepWorkPlayer.stop();
    } catch (_) {}
    _deepWorkPlaying = false;
    notifyListeners();
  }

  Future<void> toggleDeepWork() async {
    if (_deepWorkPlaying || _deepWorkUntilSessionEnd) {
      await stopDeepWork();
    } else {
      await playDeepWork();
    }
  }

  /// Süre bitiş zili (kısa, loop değil) — Deep Work focus’unu kalıcı çalmasın.
  Future<void> playCompletionChime() async {
    try {
      await _chimePlayer.setAudioContext(
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
      await _chimePlayer.stop();
      await _chimePlayer.setReleaseMode(ReleaseMode.stop);
      await _chimePlayer.setVolume(0.75);
      await _chimePlayer.play(AssetSource('sounds/focus_complete.wav'));
    } catch (e) {
      if (kDebugMode) debugPrint('Bitiş zili: $e');
    }
  }

  Future<void> shutdown() async {
    _timer?.cancel();
    await _deepWorkCompleteSub?.cancel();
    await _deepWorkStateSub?.cancel();
    await _ambientCompleteSub?.cancel();
    await _ambientStateSub?.cancel();
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
