/// Liderlik tablosu kaydı.
class LeaderboardEntryModel {
  final String kullaniciId;
  final String isim;
  final int totalCorrect;
  final int totalDurationSeconds;
  final int sira;
  final bool benMi;

  const LeaderboardEntryModel({
    required this.kullaniciId,
    required this.isim,
    this.totalCorrect = 0,
    this.totalDurationSeconds = 0,
    required this.sira,
    this.benMi = false,
  });

  /// Eski XP alanı — mini deneme sıralamasında toplam doğru.
  int get xp => totalCorrect;
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
