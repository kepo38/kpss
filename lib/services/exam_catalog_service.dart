import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../widgets/countdown_widget.dart';

/// Panelden yönetilen sınav tipleri — API + yerel yedek.
class ExamCatalogService extends ChangeNotifier {
  ExamCatalogService._();
  static final ExamCatalogService instance = ExamCatalogService._();

  static const _cacheKey = 'exam_catalog_v2';

  List<ExamTrack> _items = List<ExamTrack>.from(ExamTrack.defaults);
  bool _initialized = false;

  bool get isInitialized => _initialized;

  List<ExamTrack> get items {
    final active = _items.where((e) => e.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (active.isNotEmpty) return active;
    return List<ExamTrack>.from(ExamTrack.defaults);
  }

  ExamTrack byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return items.first;
  }

  ExamTrack forContentType(KpssType type) {
    for (final item in items) {
      if (item.contentType == type && item.id.startsWith('kpss')) {
        return item;
      }
    }
    for (final item in items) {
      if (item.contentType == type) return item;
    }
    return items.first;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          _items = decoded
              .whereType<Map>()
              .map((e) => ExamTrack.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.id.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    _initialized = true;
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final response = await http
          .get(
            ApiConfig.examTypesUri(),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      final list = decoded is Map
          ? decoded['examTypes']
          : decoded;
      if (list is! List || list.isEmpty) return;
      final parsed = list
          .whereType<Map>()
          .map((e) => ExamTrack.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      if (parsed.isEmpty) return;
      _items = parsed;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(parsed.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('exam catalog refresh: $e');
    }
  }
}
