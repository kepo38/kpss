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

  final List<AnnouncementModel> _items = [];
  final Set<int> _readIds = {};
  bool _loaded = false;

  List<AnnouncementModel> get items => List.unmodifiable(_items);
  int get unreadCount =>
      _items.where((a) => !_readIds.contains(a.id)).length;
  bool isRead(int id) => _readIds.contains(id);

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kReadIds) ?? const [];
    _readIds
      ..clear()
      ..addAll(raw.map((e) => int.tryParse(e)).whereType<int>());
    _loaded = true;
    await refresh();
  }

  Future<void> refresh() async {
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
      notifyListeners();
    } catch (e) {
      debugPrint('Duyuru listesi: $e');
    }
  }

  Future<void> markRead(int id) async {
    if (id <= 0 || _readIds.contains(id)) return;
    _readIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kReadIds,
      _readIds.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final a in _items) {
      _readIds.add(a.id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kReadIds,
      _readIds.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  AnnouncementModel? byId(int id) {
    for (final a in _items) {
      if (a.id == id) return a;
    }
    return null;
  }
}
