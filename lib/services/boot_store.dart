import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Açılışta okunan hafif durum — SharedPreferences'taki dev soru bankasını beklemez.
class BootSnapshot {
  final bool hasChosenExam;
  final String themePreference;
  final String examTrackId;

  const BootSnapshot({
    required this.hasChosenExam,
    required this.themePreference,
    required this.examTrackId,
  });

  factory BootSnapshot.defaults() => const BootSnapshot(
        hasChosenExam: false,
        themePreference: 'system',
        examTrackId: 'kpssLisans',
      );

  factory BootSnapshot.fromJson(Map<String, dynamic> json) {
    return BootSnapshot(
      hasChosenExam: json['hasChosenExam'] as bool? ?? false,
      themePreference: json['themePreference'] as String? ?? 'system',
      examTrackId: json['examTrackId'] as String? ?? 'kpssLisans',
    );
  }

  Map<String, dynamic> toJson() => {
        'hasChosenExam': hasChosenExam,
        'themePreference': themePreference,
        'examTrackId': examTrackId,
      };
}

class BootStore {
  BootStore._();

  static const _fileName = 'boot_state_v1.json';
  static BootSnapshot? _cache;
  static String? _path;

  static Future<String> _filePath() async {
    if (_path != null) return _path!;
    final dir = await getApplicationDocumentsDirectory();
    _path = p.join(dir.path, _fileName);
    return _path!;
  }

  static Future<bool> exists() async {
    if (kIsWeb) return false;
    try {
      return File(await _filePath()).exists();
    } catch (_) {
      return false;
    }
  }

  static Future<BootSnapshot> load() async {
    if (_cache != null) return _cache!;
    if (kIsWeb) {
      _cache = BootSnapshot.defaults();
      return _cache!;
    }
    try {
      final file = File(await _filePath());
      if (!await file.exists()) {
        _cache = BootSnapshot.defaults();
        return _cache!;
      }
      final raw = await file.readAsString();
      if (raw.isEmpty) {
        _cache = BootSnapshot.defaults();
        return _cache!;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _cache = BootSnapshot.defaults();
        return _cache!;
      }
      _cache = BootSnapshot.fromJson(Map<String, dynamic>.from(decoded));
      return _cache!;
    } catch (e) {
      debugPrint('BootStore load: $e');
      _cache = BootSnapshot.defaults();
      return _cache!;
    }
  }

  static Future<void> save(BootSnapshot snapshot) async {
    _cache = snapshot;
    if (kIsWeb) return;
    try {
      final file = File(await _filePath());
      await file.writeAsString(jsonEncode(snapshot.toJson()));
    } catch (e) {
      debugPrint('BootStore save: $e');
    }
  }

  static Future<void> update({
    bool? hasChosenExam,
    String? themePreference,
    String? examTrackId,
  }) async {
    final current = _cache ?? await load();
    await save(
      BootSnapshot(
        hasChosenExam: hasChosenExam ?? current.hasChosenExam,
        themePreference: themePreference ?? current.themePreference,
        examTrackId: examTrackId ?? current.examTrackId,
      ),
    );
  }

  static Future<void> syncFrom({
    required bool hasChosenExam,
    required String themePreference,
    required String examTrackId,
  }) {
    return save(
      BootSnapshot(
        hasChosenExam: hasChosenExam,
        themePreference: themePreference,
        examTrackId: examTrackId,
      ),
    );
  }
}
