import '../models/leaderboard_model.dart';
import 'daily_mini_ranking_service.dart';

class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  List<LeaderboardEntryModel> getEntries(LeaderboardPeriod period) {
    final live = DailyMiniRankingService.instance.entriesFor(period);
    if (live.isNotEmpty) return live;
    return period == LeaderboardPeriod.haftalik ? _haftalikFallback : _aylikFallback;
  }

  static const _haftalikFallback = [
    LeaderboardEntryModel(kullaniciId: '1', isim: 'Ayşe K.', totalCorrect: 0, sira: 1),
    LeaderboardEntryModel(kullaniciId: '2', isim: 'Mehmet Y.', totalCorrect: 0, sira: 2),
    LeaderboardEntryModel(kullaniciId: '3', isim: 'Zeynep A.', totalCorrect: 0, sira: 3),
  ];

  static const _aylikFallback = [
    LeaderboardEntryModel(kullaniciId: '1', isim: 'Can B.', totalCorrect: 0, sira: 1),
    LeaderboardEntryModel(kullaniciId: '2', isim: 'Elif S.', totalCorrect: 0, sira: 2),
    LeaderboardEntryModel(kullaniciId: '3', isim: 'Burak T.', totalCorrect: 0, sira: 3),
  ];
}
