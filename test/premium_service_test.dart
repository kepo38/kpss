import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/user_model.dart';
import 'package:kpss_akademi/services/database_service.dart';
import 'package:kpss_akademi/services/play_billing_service.dart';
import 'package:kpss_akademi/services/premium_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    DatabaseService.instance.setCurrentUser(
      const UserModel(
        id: 'guest',
        isim: 'Misafir',
        eposta: '',
      ),
    );
    PlayBillingService.instance.premiumNotifier.value = false;
  });

  test('isPremium uses server grant after setCurrentUser', () {
    DatabaseService.instance.setCurrentUser(
      const UserModel(
        id: 'premium-user',
        isim: 'Pro Kullanıcı',
        eposta: 'pro@example.com',
        isPremium: true,
      ),
    );

    expect(PremiumService.instance.isPremium, isTrue);
  });

  test('isPremium is false without billing or server grant', () {
    DatabaseService.instance.setCurrentUser(
      const UserModel(
        id: 'free-user',
        isim: 'Ücretsiz',
        eposta: 'free@example.com',
      ),
    );
    PlayBillingService.instance.premiumNotifier.value = false;

    expect(PremiumService.instance.isPremium, isFalse);
  });

  test('isPremium is false when profile premium is expired', () {
    DatabaseService.instance.setCurrentUser(
      UserModel(
        id: 'expired-user',
        isim: 'Süresi Dolmuş',
        eposta: 'expired@example.com',
        isPremium: true,
        premiumBitisTarihi: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    PlayBillingService.instance.premiumNotifier.value = false;

    expect(PremiumService.instance.isPremium, isFalse);
    expect(
      PremiumService.userPremiumActive(
        DatabaseService.instance.currentUser,
      ),
      isFalse,
    );
  });

  test('isPremium stays true when expiry is in the future', () {
    DatabaseService.instance.setCurrentUser(
      UserModel(
        id: 'active-user',
        isim: 'Aktif',
        eposta: 'active@example.com',
        isPremium: true,
        premiumBitisTarihi: DateTime.now().add(const Duration(days: 7)),
      ),
    );

    expect(PremiumService.instance.isPremium, isTrue);
  });

  test('copyWith can clear premium expiry on revoke', () {
    final active = UserModel(
      id: 'u1',
      isim: 'A',
      eposta: 'a@example.com',
      isPremium: true,
      isYearlyPremium: true,
      premiumProductId: 'premium_yearly',
      premiumBitisTarihi: DateTime.now().add(const Duration(days: 30)),
    );

    final revoked = active.copyWith(
      isPremium: false,
      isYearlyPremium: false,
      clearPremiumBitisTarihi: true,
      clearPremiumProductId: true,
    );

    expect(revoked.isPremium, isFalse);
    expect(revoked.isYearlyPremium, isFalse);
    expect(revoked.premiumBitisTarihi, isNull);
    expect(revoked.premiumProductId, isEmpty);
  });

  test('paywall feature list includes coach and weekly plan', () {
    final titles = PremiumService.features.map((f) => f.title).toList();
    expect(titles, contains('HEDEF KAMU Koç'));
    expect(titles, contains('Haftalık Çalışma Planı'));
  });
}
