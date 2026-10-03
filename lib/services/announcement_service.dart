import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/announcement_model.dart';
import 'app_preferences.dart';

/// Duyurular + yerel okundu durumu (profil).
class AnnouncementService extends ChangeNotifier {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  static const _kReadIds = 'announcement_read_ids';
  static const _kBaseline = 'announcement_seen_baseline_v1';
  static const _kBaselineIds = 'announcement_badge_baseline_ids_v1';

  final List<AnnouncementModel> _items = [];
  final Set<int> _readIds = {};
  final Set<int> _baselineIds = {};
  bool _prefsReady = false;
  bool _baselineDone = false;

  List<AnnouncementModel> get items => List.unmodifiable(
        _items.where(_isVisible),
      );
  int get unreadCount =>
      items.where((a) => !_readIds.contains(a.id)).length;
  bool isRead(int id) => _readIds.contains(id);

  Future<void> initialize() async {
    await _ensurePrefs();
    await refresh();
  }

  Future<void> _ensurePrefs() async {
    if (_prefsReady) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kReadIds) ?? const [];
    _readIds
      ..clear()
      ..addAll(raw.map((e) => int.tryParse(e)).whereType<int>());
    _baselineDone = prefs.getBool(_kBaseline) ?? false;
    final baselineRaw = prefs.getStringList(_kBaselineIds);
    if (baselineRaw != null) {
      _baselineIds
        ..clear()
        ..addAll(baselineRaw.map((e) => int.tryParse(e)).whereType<int>());
    } else if (_baselineDone && _readIds.isNotEmpty) {
      // Eski sürüm ilk kurulumda mevcutları «okundu» yazıyordu; rozet
      // gizlensin, chip ancak gerçek açılışta Okundu olsun.
      _baselineIds
        ..clear()
        ..addAll(_readIds);
      _readIds.clear();
      await _persistReadIds();
      await _persistBaselineIds();
    }
    await AppPreferences.firstOpenAt();
    _prefsReady = true;
  }

  bool _isVisible(AnnouncementModel a) {
    if (_baselineIds.contains(a.id)) return false;
    if (AppPreferences.isPreInstall(a.createdAt)) return false;
    return true;
  }

  Future<void> refresh() async {
    await _ensurePrefs();
    try {
      final res = await http
          .get(
            ApiConfig.announcementsUri(),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final list = jsonDecode(utf8.decode(res.bodyBytes));
      if (list is! List) return;
      _items
        ..clear()
        ..addAll(
          list.map(
            (e) => AnnouncementModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      await _applyInstallBaseline();
      notifyListeners();
    } catch (e) {
      debugPrint('Duyuru listesi: $e');
    }
  }

  /// İlk kurulumda o anki duyurular listede ve rozette yok.
  Future<void> _applyInstallBaseline() async {
    if (_baselineDone) return;
    for (final a in _items) {
      if (a.id > 0) _baselineIds.add(a.id);
    }
    await _persistBaselineIds();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBaseline, true);
    _baselineDone = true;
  }

  Future<void> _persistBaselineIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kBaselineIds,
      _baselineIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _persistReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kReadIds,
      _readIds.map((e) => e.toString()).toList(),
    );
  }

  Future<void> markRead(int id) async {
    if (id <= 0 || _readIds.contains(id)) return;
    _readIds.add(id);
    await _persistReadIds();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final a in _items) {
      _readIds.add(a.id);
    }
    await _persistReadIds();
    notifyListeners();
  }

  AnnouncementModel? byId(int id) {
    for (final a in _items) {
      if (a.id == id) return a;
    }
    return null;
  }
}
