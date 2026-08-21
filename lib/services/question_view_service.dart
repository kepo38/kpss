import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Quiz'de soru görüntülemeyi (benzersiz kullanıcı) sunucuya bildirir.
class QuestionViewService {
  QuestionViewService._();
  static final QuestionViewService instance = QuestionViewService._();

  /// Başarılıysa güncel [viewCount]; oturum yoksa veya hata olursa null.
  Future<int?> recordView(String questionId) async {
    final auth = AuthService.instance;
    if (!auth.hasBackendSession || questionId.isEmpty) return null;
    try {
      final response = await http
          .post(
            ApiConfig.questionViewUri(questionId),
            headers: {
              ...auth.authHeaders,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      return (decoded['viewCount'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
}
