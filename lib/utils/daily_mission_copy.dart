/// Günlük görev bildirim metinleri ve 4/5 FOMO koşulu.
class DailyMissionCopy {
  DailyMissionCopy._();

  static const morningHour = 9;
  static const eveningHour = 21;

  static const morningTitle = 'Günaydın';
  static const morningBody =
      'Günaydın! Bugünün ücretsiz KPSS testleri tanımlandı. '
      'Tarih ve Coğrafya barlarını yeşile boyamak için harika bir gün. '
      'İlk testine başla! 🚀';

  static const eveningTitle = 'Son 1 görev';

  static String eveningBody(String remainingSubject) =>
      'Harikasın! Bugün 4 görevi tamamladın. Son 1 test kaldı. '
      'Gece 00:00\'da hakların sıfırlanmadan önce $remainingSubject '
      'barını da yeşille ve bugünü firesiz kapat! 🔥';
}

class DailyMissionProgress {
  final int done;
  final int total;
  final List<String> remainingNames;

  const DailyMissionProgress({
    required this.done,
    required this.total,
    required this.remainingNames,
  });

  /// 4 bar dolu, son 1 ders açık.
  bool get isFourDoneOneLeft =>
      done == 4 && remainingNames.length == 1 && total == 5;

  String? get remainingName =>
      remainingNames.length == 1 ? remainingNames.first : null;
}
