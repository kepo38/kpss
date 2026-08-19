/// Günün ücretsiz mini denemesi — içerik, pencere ve teklif sabitleri.
class DailyMiniExamConstants {
  DailyMiniExamConstants._();

  static const questionCount = 20;
  static const perPool = 5;
  static const opensHour = 6;
  static const title = 'MİNİ DENEME';
  static const eyebrow = 'ÜCRETSİZ';
  static const cardHeadline = 'Günün denemesi';
  static const testIdPrefix = 'daily_mini_';

  static String get opensClock {
    final hour = opensHour.toString().padLeft(2, '0');
    return '$hour:00';
  }

  /// Tarih / Coğrafya / Vatandaşlık havuzları (ders slug).
  static const subjectPoolIds = ['tarih', 'cografya', 'vatandaslik'];

  /// Türkçe: Dil Bilgisi + Sözcükte Anlam.
  static const turkceTopicIds = ['turkce_anlam', 'turkce_dilbilgisi'];

  static const prefsState = 'daily_mini_exam_state_v1';
  static const prefsMonthlyWrongs = 'daily_mini_exam_monthly_wrongs_v1';
  static const prefsRankSnapshot = 'daily_mini_rank_snapshot_v1';
  static const prefsRankingLocked = 'daily_mini_ranking_locked_v1';
  static const prefsPendingRankingSubmit = 'daily_mini_pending_rank_submit_v1';
  static const prefsGuestFirstDate = 'daily_mini_guest_first_date_v1';

  static const ctaStartLine1 = 'Denemeye Başla';
  static const ctaStartLine2 = 'Sıralamanı Gör';
  static const ctaStart = 'Denemeye Başla · Sıralamanı Gör';
  static const ctaResume = 'Kaldığın Yerden Devam Et';
  static const ctaGuestSignIn = 'Denemeye katılmak için giriş yap';

  static String pdfUpsellMessage({int monthlyPriceTl = 299}) =>
      'Bu ay çözdüğün mini denemelerdeki tüm yanlışlarının detaylı '
      'çözümlerini PDF olarak indirmek için paket al ($monthlyPriceTl TL)';

  static String pdfUpsellShort({int monthlyPriceTl = 299}) =>
      'Bu ayın yanlış çözümleri · $monthlyPriceTl TL';
}
