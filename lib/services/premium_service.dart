import 'database_service.dart';
import 'play_billing_service.dart';

/// Premium erişim kontrolü — tüm premium modüller bu servis üzerinden doğrulanır.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  bool get isPremium {
    if (PlayBillingService.instance.premiumNotifier.value) return true;
    return DatabaseService.instance.currentUser?.isPremium ?? false;
  }

  /// Offline paket yalnızca yıllık abonelikte (Play veya sunucu grant).
  bool get isYearlyPremium {
    if (PlayBillingService.instance.isYearlyPremium) return true;
    return DatabaseService.instance.currentUser?.isYearlyPremium ?? false;
  }

  bool get canUseOfflinePack => isYearlyPremium;

  bool checkAccess() => isPremium;

  /// Premium özellik listesi (paywall ekranında gösterilir).
  static const List<PremiumFeature> features = [
    PremiumFeature(
      iconName: 'offline',
      title: 'Offline Paket (Yıllık)',
      description:
          'Kütüphanede internet olmadan tüm konu testlerini çöz. '
          'Yalnızca yıllık Premium ile.',
      yearlyOnly: true,
    ),
    PremiumFeature(
      iconName: 'checklist',
      title: 'Konu Takibi',
      description: 'ÖSYM müfredatında ilerlemenizi işaretleyin ve görün.',
    ),
    PremiumFeature(
      iconName: 'task',
      title: 'Görev Yönetimi',
      description: 'Haftalık plan, ders etiketleri ve öncelik seviyeleri.',
    ),
    PremiumFeature(
      iconName: 'cloud',
      title: 'Bulut Senkronizasyon',
      description: 'Google hesabıyla tüm cihazlarda senkron.',
    ),
    PremiumFeature(
      iconName: 'leaderboard',
      title: 'Sıralama',
      description: 'Haftalık ve aylık toplam doğru sıralaması.',
    ),
    PremiumFeature(
      iconName: 'repeat',
      title: 'Akıllı Tekrar',
      description:
          'Yanlış defteri ve zayıf konulardan günlük SRS oturumu başlat.',
    ),
    PremiumFeature(
      iconName: 'similar',
      title: 'Benzer Sorular',
      description: 'Yanlış defterinden embedding ile benzer soru seti.',
    ),
    PremiumFeature(
      iconName: 'unlimited',
      title: 'Sınırsız Konu Testi',
      description: 'Günlük ders kotası ve reklam zorunluluğu kalkar.',
    ),
  ];
}

class PremiumFeature {
  final String iconName;
  final String title;
  final String description;
  final bool yearlyOnly;

  const PremiumFeature({
    required this.iconName,
    required this.title,
    required this.description,
    this.yearlyOnly = false,
  });
}
