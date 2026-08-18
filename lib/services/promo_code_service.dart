import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class PromoRedeemResult {
  final bool success;
  final String message;
  final UserModel? user;

  const PromoRedeemResult({
    required this.success,
    required this.message,
    this.user,
  });
}

/// Promosyon kodu kullanımı — backend premium tanımlar.
class PromoCodeService {
  PromoCodeService._();
  static final PromoCodeService instance = PromoCodeService._();

  Future<PromoRedeemResult> redeem(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) {
      return const PromoRedeemResult(
        success: false,
        message: 'Promosyon kodu girin.',
      );
    }

    final auth = AuthService.instance;
    if (!auth.hasPermanentAccount) {
      return const PromoRedeemResult(
        success: false,
        message: 'Kodu kullanmak için Google hesabını bağlayın.',
      );
    }
    if (code.length > 32) {
      return const PromoRedeemResult(
        success: false,
        message: 'Promosyon kodu geçersiz.',
      );
    }

    try {
      final response = await http
          .post(
            ApiConfig.promoRedeemUri(),
            headers: {
              ...auth.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'code': code}),
          )
          .timeout(const Duration(seconds: 12));

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 401) {
        return const PromoRedeemResult(
          success: false,
          message: 'Oturum sona erdi. Tekrar giriş yapın.',
        );
      }
      if (response.statusCode != 200 || body is! Map) {
        final detail = body is Map && body['detail'] != null
            ? body['detail'].toString()
            : 'Promosyon kodu kullanılamadı.';
        return PromoRedeemResult(success: false, message: detail);
      }

      final map = Map<String, dynamic>.from(body);
      final userJson = map['user'];
      UserModel? user;
      if (userJson is Map) {
        user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
        auth.applyUserFromBackend(user);
      } else {
        await auth.refreshProfile();
        user = auth.user;
      }

      final message = (map['message'] ?? 'Premium tanımlandı.').toString();
      return PromoRedeemResult(success: true, message: message, user: user);
    } catch (e) {
      debugPrint('Promo redeem: $e');
      return const PromoRedeemResult(
        success: false,
        message: 'Sunucuya bağlanılamadı.',
      );
    }
  }
}
