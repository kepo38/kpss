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
}
