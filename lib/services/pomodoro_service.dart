import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/foundation.dart';



import '../models/pomodoro_session_model.dart';



class PomodoroService {

  PomodoroService._();

  static final PomodoroService instance = PomodoroService._();



  final List<PomodoroSessionModel> _gecmis = [];

  final AudioPlayer _ambientPlayer = AudioPlayer();

  AmbientSound _selectedSound = AmbientSound.sessiz;

  bool _audioReady = false;

  bool _ambientPlaying = false;

  double _ambientVolume = 0.42;



  List<PomodoroSessionModel> get gecmis => List.unmodifiable(_gecmis);

  AmbientSound get selectedSound => _selectedSound;

  bool get ambientPlaying => _ambientPlaying;

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

      await playAmbient();

    }

  }



  Future<void> _ensureAmbientAudio() async {

    if (_audioReady) return;

    await _ambientPlayer.setAudioContext(

      AudioContext(

        android: AudioContextAndroid(

          contentType: AndroidContentType.music,

          usageType: AndroidUsageType.media,

          audioFocus: AndroidAudioFocus.gain,

        ),

        iOS: AudioContextIOS(

          category: AVAudioSessionCategory.playback,

        ),

      ),

    );

    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);

    _audioReady = true;

  }



  Future<void> playAmbient() async {

    final path = _selectedSound.assetPath;

    if (path == null) {

      await stopAmbient();

      return;

    }

    try {

      await _ensureAmbientAudio();

      await _ambientPlayer.stop();

      await _ambientPlayer.setVolume(0);

      await _ambientPlayer.play(AssetSource(path));

      _ambientPlaying = true;

      // Yumuşak giriş — ani patlama olmasın

      const steps = 8;

      for (var i = 1; i <= steps; i++) {

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

        var v = _ambientVolume;

        for (var i = 4; i >= 0; i--) {

          await _ambientPlayer.setVolume(v * i / 4);

          await Future<void>.delayed(const Duration(milliseconds: 35));

        }

      }

      await _ambientPlayer.stop();

    } catch (_) {

      // Yoksay

    }

    _ambientPlaying = false;

  }



  Future<void> dispose() async {

    await stopAmbient();

    await _ambientPlayer.dispose();

    _audioReady = false;

  }

}


