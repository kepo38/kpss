import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/quiz_drawing_overlay.dart';
import '../widgets/quiz_stroke_codec.dart';
import 'auth_service.dart';

/// Yanlış defterinden açılan sorulardaki kalem çizimleri — soru / çözüm ayrı.
class WrongNotebookDrawingService extends ChangeNotifier {
  WrongNotebookDrawingService._();
  static final WrongNotebookDrawingService instance =
      WrongNotebookDrawingService._();

  static const _kKey = 'wrong_notebook_drawings_v1';

  final Map<String, Map<String, List<QuizStroke>>> _byQuestion = {};
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
    if (_shouldMigrateGuest(previous, scope)) {
      await _migrateScope(
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

  bool _shouldMigrateGuest(String? fromUserId, String toUserId) {
    if (fromUserId == null || fromUserId.isEmpty || fromUserId == toUserId) {
      return false;
    }
    if (!AuthService.instance.hasPermanentAccount) return false;
    return true;
  }

  Future<void> _migrateScope(
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
        fromMap.forEach((k, v) => merged[k.toString()] = v);
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
    final raw = prefs.getString(_scopedKey(_kKey));
    _byQuestion.clear();
    if (raw == null || raw.isEmpty) {
      _activeUserScopeId = _userScopeId;
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((questionId, surfaces) {
          if (questionId is! String || surfaces is! Map) return;
          final parsed = <String, List<QuizStroke>>{};
          surfaces.forEach((surface, encoded) {
            if (surface is! String) return;
            final strokes = QuizStrokeCodec.decode(encoded?.toString());
            if (strokes.isNotEmpty) {
              parsed[surface] = strokes;
            }
          });
          if (parsed.isNotEmpty) {
            _byQuestion[questionId] = parsed;
          }
        });
      }
    } catch (_) {}
    _activeUserScopeId = _userScopeId;
  }

  List<QuizStroke> strokesFor(
    String questionId, {
    required bool solution,
  }) {
    final surface = solution ? 'solution' : 'question';
    return List<QuizStroke>.unmodifiable(
      _byQuestion[questionId]?[surface] ?? const [],
    );
  }

  Future<void> saveStrokes(
    String questionId, {
    required bool solution,
    required List<QuizStroke> strokes,
  }) async {
    await initialize();
    final surface = solution ? 'solution' : 'question';
    if (strokes.isEmpty) {
      final surfaces = _byQuestion[questionId];
      surfaces?.remove(surface);
      if (surfaces != null && surfaces.isEmpty) {
        _byQuestion.remove(questionId);
      }
    } else {
      _byQuestion.putIfAbsent(questionId, () => {})[surface] =
          List<QuizStroke>.from(strokes);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_kKey);
    if (_byQuestion.isEmpty) {
      await prefs.remove(key);
      return;
    }
    final encoded = <String, dynamic>{};
    _byQuestion.forEach((questionId, surfaces) {
      final surfaceMap = <String, String>{};
      surfaces.forEach((surface, strokes) {
        if (strokes.isEmpty) return;
        surfaceMap[surface] = QuizStrokeCodec.encode(strokes);
      });
      if (surfaceMap.isNotEmpty) {
        encoded[questionId] = surfaceMap;
      }
    });
    if (encoded.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(encoded));
  }
}
