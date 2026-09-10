import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

/// Google hesabı günlük ücretsiz ders kotası (sunucu; telefon/tablet senkron).
class DailyQuotaService {
  DailyQuotaService._();
  static final DailyQuotaService instance = DailyQuotaService._();

  static const _kCache = 'daily_account_free_quota_v1';

  /// subjectSlug → bugün yakılan ücretsiz hak (0/1).
  final Map<String, int> _todayUsed = {};
  String? _cachedDay;
  String? _cachedUserId;

  int freeUsedToday(String subjectSlug) {
    _ensureTodayBucket();
    return _todayUsed[subjectSlug.trim().toLowerCase()] ?? 0;
  }

  void _ensureTodayBucket() {
    final day = _localDayKey(DateTime.now());
    if (_cachedDay == day) return;
    _cachedDay = day;
    _todayUsed.clear();
  }

  static String _localDayKey(DateTime day) {
    final local = day.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  Future<void> onUserSessionChanged() async {
    final auth = AuthService.instance;
    final userId = auth.user?.id;
    if (!auth.hasPermanentAccount || userId == null) {
      _todayUsed.clear();
      _cachedUserId = null;
      _cachedDay = null;
      return;
    }
    if (_cachedUserId != userId) {
      _todayUsed.clear();
      _cachedUserId = userId;
      _cachedDay = null;
    }
    await loadFromCache();
    unawaited(refreshFromServer());
  }

  Future<void> loadFromCache() async {
    final auth = AuthService.instance;
    if (!auth.hasPermanentAccount) return;
    final userId = auth.user?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_kCache}_$userId');
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final day = map['day']?.toString();
      final today = _localDayKey(DateTime.now());
      if (day != today) return;
      _cachedDay = today;
      _cachedUserId = userId;
      _todayUsed.clear();
      final subjects = map['subjects'];
      if (subjects is Map) {
        subjects.forEach((k, v) {
          if (v is Map && (v['freeUsed'] as num?)?.toInt() == 1) {
            _todayUsed[k.toString()] = 1;
          } else if (v is num && v.toInt() > 0) {
            _todayUsed[k.toString()] = 1;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DailyQuota cache: $e');
    }
  }

  Future<void> _persistCache() async {
    final auth = AuthService.instance;
    final userId = auth.user?.id;
    if (!auth.hasPermanentAccount || userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final subjects = <String, Map<String, int>>{
      for (final e in _todayUsed.entries)
        if (e.value > 0) e.key: {'freeUsed': 1, 'freeLimit': 1},
    };
    await prefs.setString(
      '${_kCache}_$userId',
      jsonEncode({
        'day': _localDayKey(DateTime.now()),
        'subjects': subjects,
      }),
    );
  }

  /// Sunucudan bugünkü kullanımları çek.
  Future<void> refreshFromServer({String? subject}) async {
    final auth = AuthService.instance;
    if (!auth.hasPermanentAccount) return;
    try {
      final uri = subject == null || subject.isEmpty
          ? ApiConfig.dailyQuotaUri()
          : ApiConfig.dailyQuotaUri(subject: subject);
      final response = await http
          .get(uri, headers: auth.authHeaders)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return;
      final today = _localDayKey(DateTime.now());
      _cachedDay = today;
      _cachedUserId = auth.user?.id;
      final subjects = decoded['subjects'];
      if (subjects is! Map) return;
      if (subject != null && subject.isNotEmpty) {
        final key = subject.trim().toLowerCase();
        final entry = subjects[key] ?? subjects[subject];
        if (entry is Map) {
          final used = (entry['freeUsed'] as num?)?.toInt() ?? 0;
          if (used > 0) {
            _todayUsed[key] = 1;
          } else {
            _todayUsed.remove(key);
          }
        }
      } else {
        _todayUsed.clear();
        subjects.forEach((k, v) {
          if (v is Map && ((v['freeUsed'] as num?)?.toInt() ?? 0) > 0) {
            _todayUsed[k.toString()] = 1;
          }
        });
      }
      await _persistCache();
    } catch (e) {
      if (kDebugMode) debugPrint('DailyQuota refresh: $e');
    }
  }

  /// Ücretsiz hakkı sunucuda yak (idempotent).
  Future<bool> consume(String subjectSlug) async {
    final auth = AuthService.instance;
    if (!auth.hasPermanentAccount) return false;
    final key = subjectSlug.trim().toLowerCase();
    if (key.isEmpty) return false;
    _ensureTodayBucket();
    _todayUsed[key] = 1;
    await _persistCache();
    try {
      final response = await http
          .post(
            ApiConfig.dailyQuotaUri(),
            headers: {
              ...auth.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'subject': key}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['skippedPremium'] == true) {
        _todayUsed.remove(key);
        await _persistCache();
        return false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('DailyQuota consume: $e');
      return false;
    }
  }
}
