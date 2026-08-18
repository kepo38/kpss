import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Sunucudan mobil arayüz ayarları — ana sayfa promosyon balonu.
class AppConfigService extends ChangeNotifier {
  AppConfigService._();
  static final AppConfigService instance = AppConfigService._();

  bool _loaded = false;
  bool _wrongNotebookBubbleEnabled = false;
  String _wrongNotebookBubbleLabel = 'YANLIŞLARINI GÖR';
  DateTime? _updatedAt;
  bool _authListening = false;

  /// Oturum içi kapatma — uygulama yeniden açılınca sıfırlanır.
  final Set<String> _sessionDismissedKeys = {};

  bool get isLoaded => _loaded;
  bool get wrongNotebookBubbleEnabled => _wrongNotebookBubbleEnabled;
  String get wrongNotebookBubbleLabel => _wrongNotebookBubbleLabel;

  String? _sessionDismissKey() {
    final userId = AuthService.instance.user?.id;
    if (userId == null || userId.isEmpty) return null;
    final updated = _updatedAt?.toUtc().toIso8601String();
    if (updated == null) return userId;
    return '$userId|$updated';
  }

  bool get showWrongNotebookBubble {
    if (!_wrongNotebookBubbleEnabled) return false;
    final key = _sessionDismissKey();
    if (key == null) return true;
    return !_sessionDismissedKeys.contains(key);
  }

  Future<void> initialize() async {
    _attachAuthListener();
    await refresh();
  }

  void _attachAuthListener() {
    if (_authListening) return;
    _authListening = true;
    AuthService.instance.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final res = await http
          .get(
            ApiConfig.mobileUiUri(),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final map = jsonDecode(utf8.decode(res.bodyBytes));
      if (map is! Map) return;
      _wrongNotebookBubbleEnabled =
          map['wrongNotebookBubbleEnabled'] == true;
      final label = map['wrongNotebookBubbleLabel']?.toString().trim();
      if (label != null && label.isNotEmpty) {
        _wrongNotebookBubbleLabel = label;
      }
      final rawUpdated = map['updatedAt']?.toString();
      if (rawUpdated != null && rawUpdated.isNotEmpty) {
        _updatedAt = DateTime.tryParse(rawUpdated);
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Mobil arayüz ayarları: $e');
    }
  }

  Future<void> dismissWrongNotebookBubble() async {
    final key = _sessionDismissKey();
    if (key == null) return;
    _sessionDismissedKeys.add(key);
    notifyListeners();
  }
}
