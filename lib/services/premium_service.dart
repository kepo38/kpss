import 'database_service.dart';
import 'app_config_service.dart';
import '../constants/studio_modules.dart';
import 'play_billing_service.dart';

/// Premium erişim kontrolü — tüm premium modüller bu servis üzerinden doğrulanır.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  bool get isPremium {
    final user = DatabaseService.instance.currentUser;
    if (user?.isPremium ?? false) return true;
    return PlayBillingService.instance.premiumNotifier.value;
  }

  /// Offline paket yalnızca yıllık abonelikte (Play veya sunucu grant).
  bool get isYearlyPremium {
    final user = DatabaseService.instance.currentUser;
    if (user?.isYearlyPremium ?? false) return true;
    return PlayBillingService.instance.isYearlyPremium;
  }

  bool get isOfflinePackModuleEnabled =>
      AppConfigService.instance.isStudioModuleEnabled(StudioModules.offlinePack);

  bool get canUseOfflinePack => isYearlyPremium && isOfflinePackModuleEnabled;

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
          'Yanlış defteri, telafi konuları ve zayıf konulardan günlük SRS oturumu.',
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
