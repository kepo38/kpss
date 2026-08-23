/// AdMob birim kimlikleri — production'da gerçek ID'lerle değiştirin.
class AdConstants {
  AdConstants._();

  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// Her kaç sayfa geçişinde bir interstitial gösterilecek.
  static const int pageTransitionAdInterval = 3;

  /// Ücretsiz kullanıcı — günde en fazla N sorunun adım adım detaylı çözümü
  /// (her biri ödüllü reklam ile; 6.+ Pro).
  static const int freeDetailedSolutionsPerDay = 5;

  /// @deprecated Oturum başına kota yerine [freeDetailedSolutionsPerDay] kullanılır.
  static const int freeSolutionsPerTest = freeDetailedSolutionsPerDay;

  /// Tam çözüm kilidi — UI'da gösterilen yaklaşık ödüllü reklam süresi (sn).
  static const int solutionUnlockAdApproxSeconds = 30;

  /// Yanlış defteri paylaşımı — günlük üst sınır (ekran görüntüsü yasağı bypass’ını keser).
  static const int wrongNotebookSharesPerDayFree = 1;
  static const int wrongNotebookSharesPerDayPremium = 3;
}
