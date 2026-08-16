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

  /// Offline paket yalnızca yıllık abonelikte.
  bool get isYearlyPremium => PlayBillingService.instance.isYearlyPremium;

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
      iconName: 'timer',
      title: 'Odak Modu & Pomodoro',
      description: '25/50/90 dk odak seansları, ortam sesleri, mola hatırlatıcı.',
    ),
    PremiumFeature(
      iconName: 'analytics',
      title: 'Deneme Analizi Pro',
      description:
          'GK/GY ayrımı, yayın evi karşılaştırma, çizgi grafikler, haftalık özet bildirimi.',
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
      description: 'Haftalık ve aylık XP sıralaması.',
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
