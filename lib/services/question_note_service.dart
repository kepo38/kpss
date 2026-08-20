import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Yanlış defterinden açılan soruya bağlı notlar — yerel, kullanıcı + soru ID’sine göre.
class QuestionNoteService extends ChangeNotifier {
  QuestionNoteService._();
  static final QuestionNoteService instance = QuestionNoteService._();

  static const _kKey = 'question_notes_v1';

  final Map<String, String> _notes = {};
  bool _loaded = false;
  String? _activeUserScopeId;

  String get _userScopeId => AuthService.instance.user?.id ?? 'unknown';

  String _scopedKey(String base) => '${base}_$_userScopeId';

  Future<void> onUserSessionChanged() async {
    if (!_loaded) {
      await initialize();
      return;
    }
    final scope = _userScopeId;
    if (_activeUserScopeId == scope) return;
    await _loadForCurrentUser();
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_loaded) return;
    await _loadForCurrentUser();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadForCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyKey(prefs);
    final raw = prefs.getString(_scopedKey(_kKey));
    _notes.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final text = value?.toString().trim() ?? '';
            if (key is String && key.isNotEmpty && text.isNotEmpty) {
              _notes[key] = text;
            }
          });
        }
      } catch (_) {
        // Bozuk kayıt yok sayılır.
      }
    }
    _activeUserScopeId = _userScopeId;
  }

  Future<void> _migrateLegacyKey(SharedPreferences prefs) async {
    final scoped = _scopedKey(_kKey);
    if (prefs.containsKey(scoped) || !prefs.containsKey(_kKey)) return;
    final legacy = prefs.getString(_kKey);
    if (legacy != null && legacy.isNotEmpty) {
      await prefs.setString(scoped, legacy);
    }
    await prefs.remove(_kKey);
  }

  String noteFor(String questionId) => _notes[questionId] ?? '';

  bool hasNote(String questionId) => noteFor(questionId).isNotEmpty;

  Future<void> save(String questionId, String text) async {
    await initialize();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _notes.remove(questionId);
    } else {
      _notes[questionId] = trimmed;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_kKey);
    if (_notes.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(_notes));
  }
}
