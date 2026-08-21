/// AdMob birim kimlikleri — production'da gerçek ID'lerle değiştirin.
class AdConstants {
  AdConstants._();

  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// Her kaç sayfa geçişinde bir interstitial gösterilecek.
  static const int pageTransitionAdInterval = 3;

  /// Test oturumunda ilk N tam çözüm ücretsiz; 5. ve sonrası ödüllü reklam
  /// (hangi soru / sıra fark etmez; aynı soru tekrar reklam istemez).
  static const int freeSolutionsPerTest = 4;

  /// Yanlış defteri paylaşımı — günlük üst sınır (ekran görüntüsü yasağı bypass’ını keser).
  static const int wrongNotebookSharesPerDayFree = 1;
  static const int wrongNotebookSharesPerDayPremium = 3;
}
