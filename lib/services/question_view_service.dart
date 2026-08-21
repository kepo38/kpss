import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class QuestionViewResult {
  final int viewCount;
  final int attemptCount;
  final double? correctRate;

  const QuestionViewResult({
    required this.viewCount,
    required this.attemptCount,
    this.correctRate,
  });
}

/// Quiz'de soru görüntülemeyi (benzersiz kullanıcı) sunucuya bildirir.
class QuestionViewService {
  QuestionViewService._();
  static final QuestionViewService instance = QuestionViewService._();

  /// Başarılıysa güncel görüntüleme + başarı oranı.
  /// Oturum yoksa da sunucu `correctRate` dönebilir (sayaç artmaz).
  Future<QuestionViewResult?> recordView(String questionId) async {
    if (questionId.isEmpty) return null;
    try {
      final auth = AuthService.instance;
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
      final viewCount = (decoded['viewCount'] as num?)?.toInt();
      if (viewCount == null) return null;
      return QuestionViewResult(
        viewCount: viewCount,
        attemptCount: (decoded['attemptCount'] as num?)?.toInt() ?? 0,
        correctRate: (decoded['correctRate'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
