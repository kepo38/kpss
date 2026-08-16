/// Ücretsiz test / reklam kazancı hesapları için sabitler.
class SavingsConstants {
  SavingsConstants._();

  /// Günlük görev dersleri (Güncel hariç) — her biri 1 ücretsiz test.
  static const missionSubjectIds = [
    'turkce',
    'matematik',
    'tarih',
    'cografya',
    'vatandaslik',
  ];

  /// Tek ücretsiz günlük testin tahmini TL değeri (5 × 6 = 30 TL/gün).
  static const freeTestValueTl = 6;

  /// Reklamla açılan testin tahmini TL değeri (20 × 7,5 = 150 TL).
  static const adBonusTestValueTl = 7.5;

  /// 20 test tamamlanınca bir kez gönderilecek bildirim eşiği.
  static const milestoneTotalTests = 20;

  /// Paywall’da vurgulanan aylık plan (Play fiyatı yoksa).
  static const paywallMonthlyHighlightTl = 299;

  static const prefsIs20TestNotified = 'is_20_test_notified';
}
