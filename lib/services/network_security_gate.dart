import 'auth_service.dart';
import 'network_security_service.dart';
import 'play_billing_service.dart';
import 'premium_service.dart';

/// VPN/DNS kilidi: ücretsiz kullanıcıda kilit, Premium süresince serbest.
class NetworkSecurityGate {
  NetworkSecurityGate._();

  static bool get isPremiumExempt => PremiumService.instance.isPremium;

  static Future<bool> shouldBlock(NetworkSecurityService security) async {
    final unsafe = await security.hasUnsafeConnection();
    if (!unsafe) return false;
    await ensurePremiumKnown();
    return !isPremiumExempt;
  }

  static Future<void> ensurePremiumKnown() async {
    try {
      await AuthService.instance.initialize();
    } catch (_) {}
    try {
      await PlayBillingService.instance.hydrateCachedPremium();
    } catch (_) {}
    if (isPremiumExempt) return;
    if (!AuthService.instance.hasBackendSession) return;
    try {
      await AuthService.instance
          .refreshProfile()
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
