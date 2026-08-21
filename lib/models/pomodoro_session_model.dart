import 'package:flutter/material.dart';

/// Pomodoro / odak modu oturumu.
class PomodoroSessionModel {
  final String id;
  final int sureDakika;
  final DateTime baslangic;
  final DateTime? bitis;
  final String? dersEtiketi;
  final bool tamamlandi;

  const PomodoroSessionModel({
    required this.id,
    required this.sureDakika,
    required this.baslangic,
    this.bitis,
    this.dersEtiketi,
    this.tamamlandi = false,
  });

  int get sureSaniye => sureDakika * 60;
}

enum PomodoroPreset { kisa25, orta50, uzun90, ozel }

extension PomodoroPresetExtension on PomodoroPreset {
  int get dakika {
    switch (this) {
      case PomodoroPreset.kisa25:
        return 25;
      case PomodoroPreset.orta50:
        return 50;
      case PomodoroPreset.uzun90:
        return 90;
      case PomodoroPreset.ozel:
        return 0;
    }
  }

  String get label {
    switch (this) {
      case PomodoroPreset.kisa25:
        return '25 dk';
      case PomodoroPreset.orta50:
        return '50 dk';
      case PomodoroPreset.uzun90:
        return '90 dk';
      case PomodoroPreset.ozel:
        return 'Özel';
    }
  }
}

/// Ortam sesi kataloğu — doğa, ambiyans, binaural.
enum AmbientSound {
  sessiz,
  yagmur,
  orman,
  kafe,
  kutuphane,
  binaural40,
  binaural60,
  binaural80,
  deniz,
}

enum AmbientSoundGroup { sessiz, doga, ambiyans, binaural }

extension AmbientSoundExtension on AmbientSound {
  String get label {
    switch (this) {
      case AmbientSound.sessiz:
        return 'Sessiz';
      case AmbientSound.yagmur:
        return 'Yağmur';
      case AmbientSound.orman:
        return 'Orman';
      case AmbientSound.kafe:
        return 'Kafe';
      case AmbientSound.kutuphane:
        return 'Kütüphane';
      case AmbientSound.binaural40:
        return '40 Hz';
      case AmbientSound.binaural60:
        return '60 Hz';
      case AmbientSound.binaural80:
        return '80 Hz';
      case AmbientSound.deniz:
        return 'Deniz';
    }
  }

  String get subtitle {
    switch (this) {
      case AmbientSound.sessiz:
        return 'Sessizlik';
      case AmbientSound.yagmur:
        return 'Doğa';
      case AmbientSound.orman:
        return 'Doğa';
      case AmbientSound.kafe:
        return 'Ambiyans';
      case AmbientSound.kutuphane:
        return 'Ambiyans';
      case AmbientSound.binaural40:
        return 'Binaural · odak';
      case AmbientSound.binaural60:
        return 'Binaural · denge';
      case AmbientSound.binaural80:
        return 'Binaural · uyanık';
      case AmbientSound.deniz:
        return 'Ambiyans';
    }
  }

  AmbientSoundGroup get group {
    switch (this) {
      case AmbientSound.sessiz:
        return AmbientSoundGroup.sessiz;
      case AmbientSound.yagmur:
      case AmbientSound.orman:
        return AmbientSoundGroup.doga;
      case AmbientSound.kafe:
      case AmbientSound.kutuphane:
      case AmbientSound.deniz:
        return AmbientSoundGroup.ambiyans;
      case AmbientSound.binaural40:
      case AmbientSound.binaural60:
      case AmbientSound.binaural80:
        return AmbientSoundGroup.binaural;
    }
  }

  IconData get icon {
    switch (this) {
      case AmbientSound.sessiz:
        return Icons.volume_off_outlined;
      case AmbientSound.yagmur:
        return Icons.water_drop_outlined;
      case AmbientSound.orman:
        return Icons.park_outlined;
      case AmbientSound.kafe:
        return Icons.local_cafe_outlined;
      case AmbientSound.kutuphane:
        return Icons.menu_book_outlined;
      case AmbientSound.binaural40:
      case AmbientSound.binaural60:
      case AmbientSound.binaural80:
        return Icons.graphic_eq_rounded;
      case AmbientSound.deniz:
        return Icons.waves_outlined;
    }
  }

  /// Döngüsel ortam sesi dosyası (assets/sounds/).
  String? get assetPath {
    switch (this) {
      case AmbientSound.sessiz:
        return null;
      case AmbientSound.yagmur:
        return 'sounds/ambient_rain.wav';
      case AmbientSound.orman:
        return 'sounds/ambient_forest.wav';
      case AmbientSound.kafe:
        return 'sounds/ambient_cafe.wav';
      case AmbientSound.kutuphane:
        return 'sounds/ambient_library.wav';
      case AmbientSound.binaural40:
        return 'sounds/ambient_binaural_40.wav';
      case AmbientSound.binaural60:
        return 'sounds/ambient_binaural_60.wav';
      case AmbientSound.binaural80:
        return 'sounds/ambient_binaural_80.wav';
      case AmbientSound.deniz:
        return 'sounds/ambient_ocean.wav';
    }
  }
}
