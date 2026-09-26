import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_message_model.dart';
import 'app_preferences.dart';
import 'auth_service.dart';

/// Admin'den kullanıcıya özel mesajlar.
class UserMessageService extends ChangeNotifier {
  UserMessageService._();
  static final UserMessageService instance = UserMessageService._();

  final List<UserMessageModel> _items = [];
  final Set<int> _baselineIds = {};
  bool _loaded = false;
  bool _baselineDone = false;

  static const _kBaseline = 'user_message_inbox_baseline_v1';
  static const _kBaselineIds = 'user_message_inbox_baseline_ids_v1';

  List<UserMessageModel> get items => List.unmodifiable(
        _items.where(_isVisible),
      );
  int get unreadCount => items.where((m) => !m.isRead).length;

  UserMessageModel? byId(int id) {
    for (final m in _items) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> initialize() async {
    if (_loaded) return;
    _loaded = true;
    await _ensureBaselinePrefs();
    await refresh();
  }

  Future<void> _ensureBaselinePrefs() async {
    await AppPreferences.firstOpenAt();
    final prefs = await AppPreferences.instance;
    _baselineDone = prefs.getBool(_kBaseline) ?? false;
    final raw = prefs.getStringList(_kBaselineIds) ?? const [];
    _baselineIds
      ..clear()
      ..addAll(raw.map((e) => int.tryParse(e)).whereType<int>());
  }

  bool _isVisible(UserMessageModel m) {
    if (_baselineIds.contains(m.id)) return false;
    if (AppPreferences.isPreInstall(m.createdAt)) return false;
    return true;
  }

  Future<void> _applyInstallBaseline() async {
    if (_baselineDone) return;
    for (final m in _items) {
      if (m.id > 0) _baselineIds.add(m.id);
    }
    final prefs = await AppPreferences.instance;
    await prefs.setStringList(
      _kBaselineIds,
      _baselineIds.map((e) => e.toString()).toList(),
    );
    await prefs.setBool(_kBaseline, true);
    _baselineDone = true;
  }

  Future<void> refresh() async {
    await _ensureBaselinePrefs();
    final auth = AuthService.instance;
    if (!auth.isSignedIn) {
      _items.clear();
      notifyListeners();
      return;
    }
    try {
      final res = await http
          .get(ApiConfig.meMessagesUri(), headers: auth.authHeaders)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! List) return;
      _items
        ..clear()
        ..addAll(
          body.map(
            (e) => UserMessageModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      await _applyInstallBaseline();
      notifyListeners();
    } catch (e) {
      debugPrint('Kullanıcı mesajları: $e');
    }
  }

  Future<void> markRead(int id) async {
    final idx = _items.indexWhere((m) => m.id == id);
    if (idx >= 0 && !_items[idx].isRead) {
      _items[idx] = UserMessageModel(
        id: _items[idx].id,
        title: _items[idx].title,
        body: _items[idx].body,
        isRead: true,
        createdAt: _items[idx].createdAt,
      );
      notifyListeners();
    }
    try {
      await http
          .patch(
            ApiConfig.meMessagesUri(),
            headers: {
              ...AuthService.instance.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'id': id}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = UserMessageModel(
          id: _items[i].id,
          title: _items[i].title,
          body: _items[i].body,
          isRead: true,
          createdAt: _items[i].createdAt,
        );
      }
    }
    notifyListeners();
    try {
      await http
          .patch(
            ApiConfig.meMessagesUri(),
            headers: {
              ...AuthService.instance.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'all': true}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// Okunan (veya herhangi) mesajı kullanıcı siler.
  Future<bool> deleteMessage(int id) async {
    _items.removeWhere((m) => m.id == id);
    notifyListeners();
    try {
      final res = await http
          .delete(
            ApiConfig.meMessagesUri(),
            headers: {
              ...AuthService.instance.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'id': id}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 404) return true;
      await refresh();
      return false;
    } catch (e) {
      debugPrint('Mesaj silme: $e');
      await refresh();
      return false;
    }
  }
}
