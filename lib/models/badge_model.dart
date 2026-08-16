import 'package:flutter/material.dart';

/// Rozet tanımı ve kazanım durumu.
class BadgeModel {
  final String id;
  final String ad;
  final String aciklama;
  final IconData icon;
  final int xpOdulu;
  final bool kazanildi;
  final DateTime? kazanilmaTarihi;

  const BadgeModel({
    required this.id,
    required this.ad,
    required this.aciklama,
    required this.icon,
    required this.xpOdulu,
    this.kazanildi = false,
    this.kazanilmaTarihi,
  });

  BadgeModel copyWith({bool? kazanildi, DateTime? kazanilmaTarihi}) {
    return BadgeModel(
      id: id,
      ad: ad,
      aciklama: aciklama,
      icon: icon,
      xpOdulu: xpOdulu,
      kazanildi: kazanildi ?? this.kazanildi,
      kazanilmaTarihi: kazanilmaTarihi ?? this.kazanilmaTarihi,
    );
  }
}

/// Kullanıcı gamification istatistikleri.
class UserStatsModel {
  final int xp;
  final int seviye;
  final int streak;
  final int gunlukHedefDakika;
  final int bugunCalismaDakika;
  final DateTime? sonCalismaTarihi;

  const UserStatsModel({
    this.xp = 0,
    this.seviye = 1,
    this.streak = 0,
    this.gunlukHedefDakika = 60,
    this.bugunCalismaDakika = 0,
    this.sonCalismaTarihi,
  });

  double get gunlukHedefIlerleme =>
      gunlukHedefDakika > 0 ? bugunCalismaDakika / gunlukHedefDakika : 0;

  int get sonrakiSeviyeXp => seviye * 500;

  UserStatsModel copyWith({
    int? xp,
    int? seviye,
    int? streak,
    int? gunlukHedefDakika,
    int? bugunCalismaDakika,
    DateTime? sonCalismaTarihi,
  }) {
    return UserStatsModel(
      xp: xp ?? this.xp,
      seviye: seviye ?? this.seviye,
      streak: streak ?? this.streak,
      gunlukHedefDakika: gunlukHedefDakika ?? this.gunlukHedefDakika,
      bugunCalismaDakika: bugunCalismaDakika ?? this.bugunCalismaDakika,
      sonCalismaTarihi: sonCalismaTarihi ?? this.sonCalismaTarihi,
    );
  }
}
