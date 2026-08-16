import 'package:flutter/material.dart';

import '../models/badge_model.dart';

class GamificationService {
  GamificationService._();
  static final GamificationService instance = GamificationService._();

  UserStatsModel _stats = const UserStatsModel(
    xp: 1250,
    seviye: 3,
    streak: 7,
    gunlukHedefDakika: 90,
    bugunCalismaDakika: 45,
    sonCalismaTarihi: null,
  );

  UserStatsModel get stats => _stats;

  final List<BadgeModel> _badges = _allBadges();

  List<BadgeModel> get badges => List.unmodifiable(_badges);
  List<BadgeModel> get earnedBadges => _badges.where((b) => b.kazanildi).toList();

  void addXp(int amount) {
    var xp = _stats.xp + amount;
    var level = _stats.seviye;
    while (xp >= level * 500) {
      xp -= level * 500;
      level++;
    }
    _stats = _stats.copyWith(xp: xp, seviye: level);
  }

  void recordStudyMinutes(int minutes) {
    _stats = _stats.copyWith(
      bugunCalismaDakika: _stats.bugunCalismaDakika + minutes,
      sonCalismaTarihi: DateTime.now(),
    );
    _checkBadgeUnlocks();
  }

  void setDailyGoal(int minutes) {
    _stats = _stats.copyWith(gunlukHedefDakika: minutes);
  }

  void _checkBadgeUnlocks() {
    if (_stats.streak >= 7) _unlock('streak_7');
    if (_stats.bugunCalismaDakika >= _stats.gunlukHedefDakika) {
      _unlock('daily_goal');
    }
  }

  void _unlock(String badgeId) {
    final i = _badges.indexWhere((b) => b.id == badgeId);
    if (i == -1 || _badges[i].kazanildi) return;
    _badges[i] = _badges[i].copyWith(
      kazanildi: true,
      kazanilmaTarihi: DateTime.now(),
    );
    addXp(_badges[i].xpOdulu);
  }

  static List<BadgeModel> _allBadges() {
    return [
      const BadgeModel(
        id: 'first_study',
        ad: 'İlk Adım',
        aciklama: 'İlk çalışma oturumunu tamamla',
        icon: Icons.directions_walk,
        xpOdulu: 50,
        kazanildi: true,
      ),
      const BadgeModel(
        id: 'streak_7',
        ad: '7 Gün Serisi',
        aciklama: '7 gün üst üste çalış',
        icon: Icons.local_fire_department,
        xpOdulu: 200,
        kazanildi: true,
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
