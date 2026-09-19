import 'dart:async';

import 'package:flutter/foundation.dart';
import '../widgets/countdown_widget.dart';
import 'app_preferences.dart';
import 'boot_store.dart';
import 'exam_catalog_service.dart';
/// Hedef sınav (sayaç) ve içerik mezuniyet tipi.
class KpssPreferenceService extends ChangeNotifier {
  KpssPreferenceService._();
  static final KpssPreferenceService instance = KpssPreferenceService._();

  static const storageKey = 'kpss_type_preference_v1';
  static const trackKey = 'exam_track_v1';
  static const chosenKey = 'exam_track_chosen_v1';

  String _trackId = 'kpssLisans';
  bool _hasChosenExam = false;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get hasChosenExam => _hasChosenExam;
  String get examTrackId => _trackId;

  ExamTrack get examTrack => ExamCatalogService.instance.byId(_trackId);

  /// Soru bankası / müfredat tipi.
  KpssType get kpssType => examTrack.contentType;

  void applyBootSnapshot(BootSnapshot snapshot) {
    _trackId = snapshot.examTrackId.isNotEmpty
        ? snapshot.examTrackId
        : 'kpssLisans';
    // hasChosenExam yalnızca SharedPreferences (initialize) — BootStore önbelleği değil.
    notifyListeners();
  }

  Future<void> initialize() async {
    ExamCatalogService.instance.addListener(_onCatalogChanged);
    final prefs = await AppPreferences.instance;

    final trackRaw = prefs.getString(trackKey);
    if (trackRaw != null && trackRaw.isNotEmpty) {
      _trackId = trackRaw;
    } else {
      final legacy = prefs.getString(storageKey);
      if (legacy != null) {
        final kpss = KpssType.values.firstWhere(
          (t) => t.name == legacy,
          orElse: () => KpssType.lisans,
        );
        _trackId = ExamCatalogService.instance.forContentType(kpss).id;
      }
    }
    _hasChosenExam = prefs.getBool(chosenKey) ?? false;

    _initialized = true;
    notifyListeners();
  }

  void _onCatalogChanged() => notifyListeners();

  Future<void> setExamTrack(ExamTrack value, {bool markChosen = true}) async {
    final changed = _trackId != value.id || (markChosen && !_hasChosenExam);
    _trackId = value.id;
    if (markChosen) _hasChosenExam = true;
    if (changed) notifyListeners();
    final prefs = await AppPreferences.instance;
    await prefs.setString(trackKey, value.id);
    await prefs.setString(storageKey, value.contentType.name);
    if (markChosen) {
      await prefs.setBool(chosenKey, true);
    }
    unawaited(
      BootStore.update(
        hasChosenExam: _hasChosenExam,
        examTrackId: _trackId,
      ),
    );
  }

  Future<void> setKpssType(KpssType value) async {
    await setExamTrack(ExamCatalogService.instance.forContentType(value));
  }
}
