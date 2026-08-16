import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yerel favori soru kimlikleri.
class FavoritesService extends ChangeNotifier {
  FavoritesService._();
  static final FavoritesService instance = FavoritesService._();

  static const _kKey = 'favorite_question_ids';

  final Set<String> _ids = {};
  bool _loaded = false;

  Set<String> get ids => Set.unmodifiable(_ids);

  int get count => _ids.length;

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? const [];
    _ids
      ..clear()
      ..addAll(list);
    _loaded = true;
    notifyListeners();
  }

  bool isFavorite(String questionId) => _ids.contains(questionId);

  Future<bool> toggle(String questionId) async {
    await initialize();
    if (_ids.contains(questionId)) {
      _ids.remove(questionId);
    } else {
      _ids.add(questionId);
    }
    await _persist();
    notifyListeners();
    return _ids.contains(questionId);
  }

  Future<void> remove(String questionId) async {
    await initialize();
    _ids.remove(questionId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, _ids.toList());
  }
}
