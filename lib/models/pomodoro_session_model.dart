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

enum PomodoroPreset { dk20, dk40, dk60 }

extension PomodoroPresetExtension on PomodoroPreset {
  int get dakika {
    switch (this) {
      case PomodoroPreset.dk20:
        return 20;
      case PomodoroPreset.dk40:
        return 40;
      case PomodoroPreset.dk60:
        return 60;
    }
  }

  String get label => '$dakika dk';
}

/// Ortam sesi kataloğu (Dalga / Kafe).
enum AmbientSound {
  sessiz,
  dalga,
  kafe,
}

enum AmbientSoundGroup { sessiz, doga }

extension AmbientSoundExtension on AmbientSound {
  String get label {
    switch (this) {
      case AmbientSound.sessiz:
        return 'Sessiz';
      case AmbientSound.dalga:
        return 'Dalga';
      case AmbientSound.kafe:
        return 'Kafe';
    }
  }

  String get subtitle {
    switch (this) {
      case AmbientSound.sessiz:
        return 'Sessizlik';
      case AmbientSound.dalga:
        return 'Deniz';
      case AmbientSound.kafe:
        return 'Kafe';
    }
  }

  AmbientSoundGroup get group {
    switch (this) {
      case AmbientSound.sessiz:
        return AmbientSoundGroup.sessiz;
      case AmbientSound.dalga:
      case AmbientSound.kafe:
        return AmbientSoundGroup.doga;
    }
  }

  IconData get icon {
    switch (this) {
      case AmbientSound.sessiz:
        return Icons.volume_off_outlined;
      case AmbientSound.dalga:
        return Icons.waves_rounded;
      case AmbientSound.kafe:
        return Icons.local_cafe_outlined;
    }
  }

  /// Döngüsel ortam sesi dosyası (assets/sounds/).
  String? get assetPath {
    switch (this) {
      case AmbientSound.sessiz:
        return null;
      case AmbientSound.dalga:
        return 'sounds/ambient_wave.mp3';
      case AmbientSound.kafe:
        return 'sounds/ambient_cafe.mp3';
    }
  }
}
