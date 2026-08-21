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

enum PomodoroPreset { kisa25, orta30, orta50, uzun90, ozel }

extension PomodoroPresetExtension on PomodoroPreset {
  int get dakika {
    switch (this) {
      case PomodoroPreset.kisa25:
        return 25;
      case PomodoroPreset.orta30:
        return 30;
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
      case PomodoroPreset.orta30:
        return '30 dk';
      case PomodoroPreset.orta50:
        return '50 dk';
      case PomodoroPreset.uzun90:
        return '90 dk';
      case PomodoroPreset.ozel:
        return 'Özel';
    }
  }
}

/// Ortam sesi kataloğu — yalnızca Sessiz + doğa (yağmur / orman).
enum AmbientSound {
  sessiz,
  yagmur,
  orman,
}

enum AmbientSoundGroup { sessiz, doga }

extension AmbientSoundExtension on AmbientSound {
  String get label {
    switch (this) {
      case AmbientSound.sessiz:
        return 'Sessiz';
      case AmbientSound.yagmur:
        return 'Yağmur';
      case AmbientSound.orman:
        return 'Orman';
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
    }
  }

  AmbientSoundGroup get group {
    switch (this) {
      case AmbientSound.sessiz:
        return AmbientSoundGroup.sessiz;
      case AmbientSound.yagmur:
      case AmbientSound.orman:
        return AmbientSoundGroup.doga;
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
    }
  }
}
