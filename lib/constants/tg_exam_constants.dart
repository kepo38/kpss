/// Türkiye Geneli deneme oturumu sabitleri.
class TgExamConstants {
  TgExamConstants._();

  /// Oturum süresi — 2 saat 10 dakika, geriye sayım.
  static const examDurationMinutes = 130;

  /// Kalan süre bu eşiğe inince bir kez uyarı sesi çalar.
  static const warningBeforeEndMinutes = 10;

  /// Toplam soru — GY 60 + GK 60.
  static const questionCount = 120;
  static const gyQuestionCount = 60;
  static const gkQuestionCount = 60;

  /// GK bölümü bu indeksten başlar (0 tabanlı).
  static const gkStartIndex = gyQuestionCount;
}
