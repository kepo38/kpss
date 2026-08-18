import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/announcement_model.dart';

/// Duyurular + yerel okundu durumu (profil).
class AnnouncementService extends ChangeNotifier {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  static const _kReadIds = 'announcement_read_ids';
  static const _kBaseline = 'announcement_seen_baseline_v1';

  final List<AnnouncementModel> _items = [];
  final Set<int> _readIds = {};
  bool _prefsReady = false;
  bool _baselineDone = false;

  List<AnnouncementModel> get items => List.unmodifiable(_items);
  int get unreadCount =>
      _items.where((a) => !_readIds.contains(a.id)).length;
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
    _prefsReady = true;
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

  /// İlk kurulumda o anki duyurular okunmuş sayılır; rozet yalnızca
  /// bundan sonra yayınlananlar için çıkar.
  Future<void> _applyInstallBaseline() async {
    if (_baselineDone) return;
    if (_readIds.isEmpty) {
      for (final a in _items) {
        if (a.id > 0) _readIds.add(a.id);
      }
      await _persistReadIds();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBaseline, true);
    _baselineDone = true;
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
