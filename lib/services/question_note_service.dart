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

  Future<void> onUserSessionChanged({String? previousUserId}) async {
    var previous = previousUserId ?? _activeUserScopeId;
    if (!_loaded) {
      await initialize();
    }
    final scope = _userScopeId;
    if (previous == null || previous.isEmpty) {
      previous = await _inferGuestUserId(scope);
    }
    if (previous == null || previous.isEmpty || previous == scope) return;
    final prefs = await SharedPreferences.getInstance();
    if (_shouldMigrateGuestNotes(previous, scope)) {
      await _migrateNotesScope(
        prefs,
        fromUserId: previous,
        toUserId: scope,
      );
    }
    await _loadForCurrentUser();
    notifyListeners();
  }

  Future<String?> _inferGuestUserId(String toUserId) async {
    if (!AuthService.instance.hasPermanentAccount) return null;
    final prefs = await SharedPreferences.getInstance();
    const localGuestKey = 'local_guest_id';
    final localGuest = prefs.getString(localGuestKey);
    if (localGuest == null ||
        localGuest.isEmpty ||
        localGuest == toUserId) {
      return null;
    }
    final fromKey = '${_kKey}_$localGuest';
    final fromRaw = prefs.getString(fromKey);
    if (fromRaw == null || fromRaw.isEmpty) return null;
    return localGuest;
  }

  bool _shouldMigrateGuestNotes(String? fromUserId, String toUserId) {
    if (fromUserId == null || fromUserId.isEmpty || fromUserId == toUserId) {
      return false;
    }
    if (!AuthService.instance.hasPermanentAccount) return false;
    return true;
  }

  Future<void> _migrateNotesScope(
    SharedPreferences prefs, {
    required String fromUserId,
    required String toUserId,
  }) async {
    final fromKey = '${_kKey}_$fromUserId';
    final toKey = '${_kKey}_$toUserId';
    final fromRaw = prefs.getString(fromKey);
    if (fromRaw == null || fromRaw.isEmpty) return;
    final merged = <String, dynamic>{};
    try {
      final fromMap = jsonDecode(fromRaw);
      if (fromMap is Map) {
        fromMap.forEach((k, v) {
          merged[k.toString()] = v;
        });
      }
    } catch (_) {
      return;
    }
    final toRaw = prefs.getString(toKey);
    if (toRaw != null && toRaw.isNotEmpty) {
      try {
        final toMap = jsonDecode(toRaw);
        if (toMap is Map) {
          toMap.forEach((k, v) {
            merged.putIfAbsent(k.toString(), () => v);
          });
        }
      } catch (_) {}
    }
    await prefs.setString(toKey, jsonEncode(merged));
    await prefs.remove(fromKey);
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
