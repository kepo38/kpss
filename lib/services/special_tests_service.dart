import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/special_test_models.dart';

/// Sanal özel test kategorileri — API + kısa yerel önbellek.
class SpecialTestsService extends ChangeNotifier {
  SpecialTestsService._();
  static final SpecialTestsService instance = SpecialTestsService._();

  static const _cacheKey = 'special_tests_cache_v1';
  static const mapGeographyId = 'haritalarla-cografya';
  static const mapGeographyTestPrefix = 'special_map_cografya';
  static const mapGeographyTopicId = 'haritalarla-cografya';

  List<SpecialTestCategory> _categories = [];
  bool _loading = false;
  String? _error;

  List<SpecialTestCategory> get categories => List.unmodifiable(_categories);
  bool get isLoading => _loading;
  String? get error => _error;

  SpecialTestCategory? categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http
          .get(
            ApiConfig.specialTestsUri(),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _categories = _parseCategories(body);
        _error = null;
        await _persistCache();
      } else {
        _error = 'Özel testler alınamadı (${response.statusCode}).';
        await _loadCache();
      }
    } catch (e) {
      debugPrint('SpecialTestsService.refresh: $e');
      _error = 'Özel testler yüklenemedi.';
      await _loadCache();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> ensureLoaded() async {
    if (_categories.isNotEmpty || _loading) return;
    await _loadCache();
    if (_categories.isEmpty) {
      await refresh();
    } else {
      notifyListeners();
      await refresh();
    }
  }

  List<SpecialTestCategory> _parseCategories(Map<String, dynamic> body) {
    final raw = body['categories'] as List<dynamic>? ?? const [];
    return raw
        .map(
          (e) => SpecialTestCategory.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode({
        'categories': _categories
            .map(
              (c) => {
                'id': c.id,
                'title': c.title,
                'subjectId': c.subjectId,
                'questionCount': c.questionCount,
                'tests': c.tests
                    .map(
                      (t) => {
                        'id': t.id,
                        'title': t.title,
                        'questionCount': t.questionCount,
                        'questionIds': t.questionIds,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      }),
    );
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final body = jsonDecode(raw) as Map<String, dynamic>;
      _categories = _parseCategories(body);
    } catch (_) {}
  }
}
