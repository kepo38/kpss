import '../models/leaderboard_model.dart';

class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  List<LeaderboardEntryModel> getEntries(LeaderboardPeriod period) {
    final base = period == LeaderboardPeriod.haftalik
        ? _haftalik
        : _aylik;
    return base;
  }

  static const _haftalik = [
    LeaderboardEntryModel(kullaniciId: '1', isim: 'Ayşe K.', xp: 3200, sira: 1),
    LeaderboardEntryModel(kullaniciId: '2', isim: 'Mehmet Y.', xp: 2850, sira: 2),
    LeaderboardEntryModel(kullaniciId: '3', isim: 'Zeynep A.', xp: 2600, sira: 3),
    LeaderboardEntryModel(
      kullaniciId: 'demo-user',
      isim: 'Siz',
      xp: 1250,
      sira: 12,
      benMi: true,
    ),
  ];

  static const _aylik = [
    LeaderboardEntryModel(kullaniciId: '1', isim: 'Can B.', xp: 12400, sira: 1),
    LeaderboardEntryModel(kullaniciId: '2', isim: 'Elif S.', xp: 11200, sira: 2),
    LeaderboardEntryModel(kullaniciId: '3', isim: 'Burak T.', xp: 9800, sira: 3),
    LeaderboardEntryModel(
      kullaniciId: 'demo-user',
      isim: 'Siz',
      xp: 1250,
      sira: 45,
      benMi: true,
    ),
  ];
}
