import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/badge_model.dart';
import '../models/content_models.dart';
import 'content_bank_service.dart';

/// XP, seviye, seri ve rozetler — yerel kalıcı, sabit demo değer yok.
class GamificationService extends ChangeNotifier {
  GamificationService._();
  static final GamificationService instance = GamificationService._();

  static const _kStats = 'gamification_stats_v1';
  static const _kBadges = 'gamification_badges_v1';

  static const xpPerCorrect = 10;
  static const xpPerWrong = 2;
  static const xpTestBonus = 15;
  static const xpPerStudyMinute = 1;

  bool _loaded = false;
  int _totalXp = 0;
  UserStatsModel _stats = const UserStatsModel();
  List<BadgeModel> _badges = _allBadges();

  UserStatsModel get stats => _stats;
  int get totalXp => _totalXp;

  List<BadgeModel> get badges => List.unmodifiable(_badges);
  List<BadgeModel> get earnedBadges =>
      _badges.where((b) => b.kazanildi).toList();

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStats);
    if (raw != null) {
      try {
        final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _totalXp = (json['totalXp'] as num?)?.toInt() ?? 0;
        _stats = UserStatsModel(
          xp: 0,
          seviye: 1,
          streak: (json['streak'] as num?)?.toInt() ?? 0,
          gunlukHedefDakika:
              (json['gunlukHedefDakika'] as num?)?.toInt() ?? 60,
          bugunCalismaDakika:
              (json['bugunCalismaDakika'] as num?)?.toInt() ?? 0,
          sonCalismaTarihi: json['sonCalismaTarihi'] == null
              ? null
              : DateTime.tryParse(json['sonCalismaTarihi'] as String),
        );
        _refreshLevelFromTotal();
        _rollDailyMinutesIfNeeded();
      } catch (e) {
        debugPrint('Gamification stats parse: $e');
        await _bootstrapFromAttempts();
      }
    } else {
      await _bootstrapFromAttempts();
      await _persist();
    }

    _restoreBadges(prefs.getString(_kBadges));
    _syncBadgeUnlocks(awardXp: false);
    _loaded = true;
    await _persist();
    notifyListeners();
  }

  /// Konu testi / mini deneme bitince XP ve seri güncelle.
  Future<void> recordTestCompleted({
    required int correct,
    required int wrong,
    required Duration duration,
  }) async {
    await initialize();
    final minutes = duration.inMinutes.clamp(0, 240);
    final gained = xpTestBonus +
        correct * xpPerCorrect +
        wrong * xpPerWrong +
        minutes * xpPerStudyMinute;
    _applyStudyDay(minutes: minutes);
    _addTotalXp(gained);
    _syncBadgeUnlocks(awardXp: true);
    await _persist();
    notifyListeners();
  }

  int xpForCompletedTest({
    required int correct,
    required int wrong,
    required Duration duration,
  }) {
    final minutes = duration.inMinutes.clamp(0, 240);
    return xpTestBonus +
        correct * xpPerCorrect +
        wrong * xpPerWrong +
        minutes * xpPerStudyMinute;
  }

  /// Sonuç ekranı için: kayıt henüz yapılmasa da seri tahmini.
  int previewStreakAfterTest() {
    final now = DateTime.now();
    final last = _stats.sonCalismaTarihi?.toLocal();
    if (last == null) return 1;
    if (_isSameDay(last, now)) {
      return _stats.streak < 1 ? 1 : _stats.streak;
    }
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    if (_isSameDay(last, yesterday)) return _stats.streak + 1;
    return 1;
  }

  void addXp(int amount) {
    if (amount <= 0) return;
    _addTotalXp(amount);
    unawaitedPersist();
    notifyListeners();
  }

  void recordStudyMinutes(int minutes) {
    if (minutes <= 0) return;
    unawaited(_recordStudyMinutesAsync(minutes));
  }

  Future<void> _recordStudyMinutesAsync(int minutes) async {
    await initialize();
    _applyStudyDay(minutes: minutes);
    _addTotalXp(minutes * xpPerStudyMinute);
    _syncBadgeUnlocks(awardXp: true);
    await _persist();
    notifyListeners();
  }

  Future<void> setDailyGoal(int minutes) async {
    await initialize();
    _stats = _stats.copyWith(gunlukHedefDakika: minutes.clamp(15, 300));
    _syncBadgeUnlocks(awardXp: true);
    await _persist();
    notifyListeners();
  }

  Future<void> onPracticeExamAdded({required int totalExams}) async {
    await initialize();
    if (totalExams >= 5) _unlock('exam_5', awardXp: true);
    await _persist();
    notifyListeners();
  }

  void unawaitedPersist() {
    // ignore: discarded_futures
    _persist();
  }

  Future<void> _bootstrapFromAttempts() async {
    await ContentBankService.instance.initialize();
    final attempts = ContentBankService.instance.allAttempts;
    var total = 0;
    var todayMinutes = 0;
    DateTime? last;
    final now = DateTime.now();
    for (final a in attempts) {
      total += _xpForAttempt(a);
      final local = a.completedAt.toLocal();
      if (last == null || local.isAfter(last)) last = local;
      if (_isSameDay(local, now)) {
        todayMinutes += a.duration.inMinutes.clamp(0, 240);
      }
    }
    _totalXp = total;
    _stats = UserStatsModel(
      streak: _streakFromAttempts(attempts),
      gunlukHedefDakika: 60,
      bugunCalismaDakika: todayMinutes,
      sonCalismaTarihi: last,
    );
    _refreshLevelFromTotal();
  }

  static int _xpForAttempt(TestAttemptModel a) {
    return xpTestBonus +
        a.correct * xpPerCorrect +
        a.wrong * xpPerWrong +
        a.duration.inMinutes.clamp(0, 240) * xpPerStudyMinute;
  }

  static int _streakFromAttempts(List<TestAttemptModel> attempts) {
    if (attempts.isEmpty) return 0;
    final days = attempts
        .map((a) {
          final d = a.completedAt.toLocal();
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final yesterday = todayKey.subtract(const Duration(days: 1));
    if (days.first != todayKey && days.first != yesterday) return 0;
    var streak = 1;
    var cursor = days.first;
    for (var i = 1; i < days.length; i++) {
      final expected = cursor.subtract(const Duration(days: 1));
      if (days[i] != expected) break;
      streak++;
      cursor = days[i];
    }
    return streak;
  }

  void _applyStudyDay({required int minutes}) {
    _rollDailyMinutesIfNeeded();
    final now = DateTime.now();
    final last = _stats.sonCalismaTarihi?.toLocal();
    var streak = _stats.streak;
    if (last == null) {
      streak = 1;
    } else if (!_isSameDay(last, now)) {
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
      if (_isSameDay(last, yesterday)) {
        streak += 1;
      } else {
        streak = 1;
      }
    }
    _stats = _stats.copyWith(
      bugunCalismaDakika: _stats.bugunCalismaDakika + minutes,
      sonCalismaTarihi: now,
      streak: streak,
    );
  }

  void _rollDailyMinutesIfNeeded() {
    final last = _stats.sonCalismaTarihi?.toLocal();
    final now = DateTime.now();
    if (last != null && !_isSameDay(last, now)) {
      _stats = _stats.copyWith(bugunCalismaDakika: 0);
    }
  }

  void _addTotalXp(int amount) {
    if (amount <= 0) return;
    _totalXp += amount;
    _refreshLevelFromTotal();
  }

  void _refreshLevelFromTotal() {
    var level = 1;
    var remaining = _totalXp;
    while (remaining >= level * 500) {
      remaining -= level * 500;
      level++;
    }
    _stats = _stats.copyWith(xp: remaining, seviye: level);
  }

  void _syncBadgeUnlocks({required bool awardXp}) {
    if (_stats.streak >= 7) _unlock('streak_7', awardXp: awardXp);
    if (_stats.bugunCalismaDakika >= _stats.gunlukHedefDakika &&
        _stats.bugunCalismaDakika > 0) {
      _unlock('daily_goal', awardXp: awardXp);
    }
    if (ContentBankService.instance.allAttempts.isNotEmpty) {
      _unlock('first_study', awardXp: awardXp);
    }
  }

  void _unlock(String badgeId, {required bool awardXp}) {
    final i = _badges.indexWhere((b) => b.id == badgeId);
    if (i == -1 || _badges[i].kazanildi) return;
    _badges[i] = _badges[i].copyWith(
      kazanildi: true,
      kazanilmaTarihi: DateTime.now(),
    );
    if (awardXp) _addTotalXp(_badges[i].xpOdulu);
  }

  void _restoreBadges(String? raw) {
    _badges = _allBadges();
    if (raw == null || raw.isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (var i = 0; i < _badges.length; i++) {
        final entry = map[_badges[i].id];
        if (entry is! Map) continue;
        final earned = entry['kazanildi'] == true;
        if (!earned) continue;
        _badges[i] = _badges[i].copyWith(
          kazanildi: true,
          kazanilmaTarihi: entry['kazanilmaTarihi'] == null
              ? null
              : DateTime.tryParse(entry['kazanilmaTarihi'] as String),
        );
      }
    } catch (e) {
      debugPrint('Gamification badges parse: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kStats,
      jsonEncode({
        'totalXp': _totalXp,
        'streak': _stats.streak,
        'gunlukHedefDakika': _stats.gunlukHedefDakika,
        'bugunCalismaDakika': _stats.bugunCalismaDakika,
        'sonCalismaTarihi': _stats.sonCalismaTarihi?.toIso8601String(),
      }),
    );
    final badgeMap = <String, dynamic>{};
    for (final b in _badges) {
      if (!b.kazanildi) continue;
      badgeMap[b.id] = {
        'kazanildi': true,
        'kazanilmaTarihi': b.kazanilmaTarihi?.toIso8601String(),
      };
    }
    await prefs.setString(_kBadges, jsonEncode(badgeMap));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static List<BadgeModel> _allBadges() {
    return [
      const BadgeModel(
        id: 'first_study',
        ad: 'İlk Adım',
        aciklama: 'İlk çalışma oturumunu tamamla',
        icon: Icons.directions_walk,
        xpOdulu: 50,
      ),
      const BadgeModel(
        id: 'streak_7',
        ad: '7 Gün Serisi',
        aciklama: '7 gün üst üste çalış',
        icon: Icons.local_fire_department,
        xpOdulu: 200,
      ),
      const BadgeModel(
        id: 'daily_goal',
        ad: 'Günlük Hedef',
        aciklama: 'Günlük hedefini tamamla',
        icon: Icons.flag_outlined,
        xpOdulu: 100,
      ),
      const BadgeModel(
        id: 'exam_5',
        ad: '5 Deneme',
        aciklama: '5 deneme sonucu gir',
        icon: Icons.assignment_outlined,
        xpOdulu: 300,
      ),
      const BadgeModel(
        id: 'topic_master',
        ad: 'Konu Ustası',
        aciklama: 'Bir dersin tüm konularını tamamla',
        icon: Icons.school_outlined,
        xpOdulu: 500,
      ),
      const BadgeModel(
        id: 'focus_10',
        ad: 'Odaklı Çalışkan',
        aciklama: '10 pomodoro oturumu tamamla',
        icon: Icons.timer_outlined,
        xpOdulu: 250,
      ),
    ];
  }
}
