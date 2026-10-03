/// Detaylı çözüm günlük kotası — cihaz geneli (SharedPreferences).
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_constants.dart';
import 'app_preferences.dart';

class DailySolutionQuotaService {
  DailySolutionQuotaService._();
  static final DailySolutionQuotaService instance = DailySolutionQuotaService._();

  static const _kDay = 'daily_detailed_solution_day_v1';
  static const _kQuestionIds = 'daily_detailed_solution_ids_v1';

  String _todayKey([DateTime? now]) {
    final d = (now ?? DateTime.now()).toLocal();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _ensureTodayBucket(SharedPreferences prefs) async {
    final today = _todayKey();
    if (prefs.getString(_kDay) == today) return;
    await prefs.setString(_kDay, today);
    await prefs.setStringList(_kQuestionIds, const []);
  }

  Future<Set<String>> unlockedQuestionIdsToday() async {
    final prefs = await AppPreferences.instance;
    await _ensureTodayBucket(prefs);
    return (prefs.getStringList(_kQuestionIds) ?? const []).toSet();
  }

  Future<int> usedToday() async {
    final ids = await unlockedQuestionIdsToday();
    return ids.length;
  }

  Future<int> remainingToday() async {
    final used = await usedToday();
    final left = AdConstants.freeDetailedSolutionsPerDay - used;
    return left < 0 ? 0 : left;
  }

  Future<bool> isUnlockedToday(String questionId) async {
    if (questionId.isEmpty) return false;
    final ids = await unlockedQuestionIdsToday();
    return ids.contains(questionId);
  }

  /// Yeni soru için kotadan düşer; bugün açılmış soru tekrar ücretsiz.
  Future<bool> tryUnlock(String questionId) async {
    if (questionId.isEmpty) return false;
    final prefs = await AppPreferences.instance;
    await _ensureTodayBucket(prefs);
    final ids = (prefs.getStringList(_kQuestionIds) ?? []).toSet();
    if (ids.contains(questionId)) return true;
    if (ids.length >= AdConstants.freeDetailedSolutionsPerDay) return false;
    ids.add(questionId);
    await prefs.setStringList(_kQuestionIds, ids.toList());
    return true;
  }
}
