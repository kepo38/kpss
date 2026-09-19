import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_service.dart';
import 'iap_constants.dart';
import 'play_billing_service.dart';

/// Play entitlement bilgisini sunucuya iletir (offline pack gate için).
class PremiumSyncService {
  PremiumSyncService._();
  static final PremiumSyncService instance = PremiumSyncService._();

  Future<bool> syncToBackend({
    bool? isPremium,
    String? productId,
    DateTime? expiresAt,
  }) async {
    final auth = AuthService.instance;
    if (!auth.hasBackendSession) return false;

    final billing = PlayBillingService.instance;
    final premium = isPremium ?? billing.premiumNotifier.value;
    final pid = productId ??
        (premium ? (billing.activeProductId ?? '') : '');

    try {
      final response = await http
          .post(
            ApiConfig.premiumSyncUri(),
            headers: {
              ...auth.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'productId': pid,
              'isPremium': premium,
              'expiresAt': expiresAt?.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint('Premium sync HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Premium sync failed: $e');
      return false;
    }
  }

  /// Yerel Play önbelleğinden sunucuya senkron.
  Future<void> syncFromLocalBilling() async {
    final billing = PlayBillingService.instance;
    final premium = billing.premiumNotifier.value;
    DateTime? expiry;
    if (premium) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(IapConstants.premiumExpiryPrefsKey);
      if (raw != null) expiry = DateTime.tryParse(raw);
    }
    await syncToBackend(
      isPremium: premium,
      productId: premium ? (billing.activeProductId ?? '') : '',
      expiresAt: expiry,
    );
  }

  Future<void> syncIfYearlyActive() async {
    final billing = PlayBillingService.instance;
    if (!billing.premiumNotifier.value) return;
    if (billing.activeProductId != IapConstants.yearlySubscriptionId) return;
    await syncFromLocalBilling();
  }
}
