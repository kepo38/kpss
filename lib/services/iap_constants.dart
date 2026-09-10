/// Google Play Console'da tanımlanacak abonelik ürün kimlikleri.
///
/// Play Console → Monetize → Products → Subscriptions
/// Base plan ID'leri bu product ID'lerin altında oluşturulur.
class IapConstants {
  IapConstants._();

  /// Aylık premium abonelik
  static const String monthlySubscriptionId = 'kpss_premium_monthly';

  /// Yıllık premium abonelik
  static const String yearlySubscriptionId = 'kpss_premium_yearly';

  static const Set<String> subscriptionIds = {
    monthlySubscriptionId,
    yearlySubscriptionId,
  };

  /// Mağaza fiyatı gelene kadar paywall'da gösterilen referans fiyatlar
  /// (Play Console ile aynı tutulmalı). Nihai tutar Google Play'den gelir.
  static const String monthlyFallbackPrice = '₺149,99';
  static const String monthlyIntroFallbackPrice = '₺79,99';
  static const String yearlyFallbackPrice = '₺999,00';

  static const String premiumPrefsKey = 'is_premium_active';
  static const String premiumProductPrefsKey = 'premium_product_id';
  static const String premiumExpiryPrefsKey = 'premium_expiry_iso';
  static const String ownedPackProductsPrefsKey = 'owned_exam_pack_product_ids';
}
