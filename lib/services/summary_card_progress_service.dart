import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Özet konu kartı: favori / biliyorum / unuttum (zayıf) — kullanıcı scope.
class SummaryCardProgressService extends ChangeNotifier {
  SummaryCardProgressService._();
  static final SummaryCardProgressService instance =
      SummaryCardProgressService._();

  final Set<String> _favoriteIds = {};
  final Set<String> _weakIds = {};
  final Set<String> _knownIds = {};
  bool _loaded = false;
  String? _activeUserId;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  Set<String> get weakIds => Set.unmodifiable(_weakIds);
  Set<String> get knownIds => Set.unmodifiable(_knownIds);

  int get favoriteCount => _favoriteIds.length;
  int get weakCount => _weakIds.length;

  String get _userId => AuthService.instance.user?.id ?? 'guest';

  String _key(String suffix) => 'summary_card_${suffix}_$_userId';

  Future<void> initialize() async {
    if (_loaded && _activeUserId == _userId) return;
    await _loadForCurrentUser();
    _loaded = true;
    notifyListeners();
  }

  Future<void> onUserSessionChanged() async {
    if (!_loaded) {
      await initialize();
      return;
    }
    if (_activeUserId == _userId) return;
    await _loadForCurrentUser();
    notifyListeners();
  }

  Future<void> _loadForCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userId;
    _favoriteIds
      ..clear()
      ..addAll(prefs.getStringList(_key('fav')) ?? const []);
    _weakIds
      ..clear()
      ..addAll(prefs.getStringList(_key('weak')) ?? const []);
    _knownIds
      ..clear()
      ..addAll(prefs.getStringList(_key('known')) ?? const []);
    _activeUserId = userId;
  }

  bool isFavorite(String cardId) => _favoriteIds.contains(cardId);
  bool isWeak(String cardId) => _weakIds.contains(cardId);
  bool isKnown(String cardId) => _knownIds.contains(cardId);

  Future<bool> toggleFavorite(String cardId) async {
    await initialize();
    if (_favoriteIds.contains(cardId)) {
      _favoriteIds.remove(cardId);
    } else {
      _favoriteIds.add(cardId);
    }
    await _persist();
    notifyListeners();
    return _favoriteIds.contains(cardId);
  }

  Future<void> markKnown(String cardId) async {
    await initialize();
    _knownIds.add(cardId);
    _weakIds.remove(cardId);
    await _persist();
    notifyListeners();
  }

  Future<void> markWeak(String cardId) async {
    await initialize();
    _weakIds.add(cardId);
    _knownIds.remove(cardId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeFavorite(String cardId) async {
    await initialize();
    _favoriteIds.remove(cardId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeWeak(String cardId) async {
    await initialize();
    _weakIds.remove(cardId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key('fav'), _favoriteIds.toList());
    await prefs.setStringList(_key('weak'), _weakIds.toList());
    await prefs.setStringList(_key('known'), _knownIds.toList());
  }
}
