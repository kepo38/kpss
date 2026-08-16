/// Liderlik tablosu kaydı.
class LeaderboardEntryModel {
  final String kullaniciId;
  final String isim;
  final int xp;
  final int sira;
  final bool benMi;

  const LeaderboardEntryModel({
    required this.kullaniciId,
    required this.isim,
    required this.xp,
    required this.sira,
    this.benMi = false,
  });
}

enum LeaderboardPeriod { haftalik, aylik }

extension LeaderboardPeriodExtension on LeaderboardPeriod {
  String get label {
    switch (this) {
      case LeaderboardPeriod.haftalik:
        return 'Haftalık';
      case LeaderboardPeriod.aylik:
        return 'Aylık';
    }
  }
}
