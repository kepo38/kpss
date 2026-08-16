import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import '../screens/premium/premium_paywall_screen.dart';

/// Premium olmayan kullanıcıları paywall'a yönlendirir.
class PremiumGate {
  PremiumGate._();

  static bool get isPremium => PremiumService.instance.isPremium;

  /// Premium değilse paywall gösterir; true dönerse devam edilebilir.
  static Future<bool> requirePremium(BuildContext context) async {
    if (isPremium) return true;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PremiumPaywallScreen(),
      ),
    );
    return result == true || isPremium;
  }

  /// Premium modüle navigasyon — erişim yoksa paywall açar.
  static Future<void> navigate(
    BuildContext context,
    Widget Function() screenBuilder,
  ) async {
    if (await requirePremium(context) && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => screenBuilder()),
      );
    }
  }
}
