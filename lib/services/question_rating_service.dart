import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class QuestionRatingSummary {
  final int? userRating;
  final double? averageRating;
  final int ratingCount;

  const QuestionRatingSummary({
    required this.userRating,
    required this.averageRating,
    required this.ratingCount,
  });

  factory QuestionRatingSummary.fromJson(Map<String, dynamic> json) {
    final average = json['averageRating'];
    return QuestionRatingSummary(
      userRating: (json['userRating'] as num?)?.toInt(),
      averageRating: average is num ? average.toDouble() : null,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuestionRatingException implements Exception {
  final String message;
  const QuestionRatingException(this.message);

  @override
  String toString() => message;
}

class QuestionRatingService {
  QuestionRatingService._();
  static final QuestionRatingService instance = QuestionRatingService._();

  final Map<String, QuestionRatingSummary> _cache = {};

  String _cacheKey(String questionId) {
    final userId = AuthService.instance.user?.id ?? "anonymous";
    return "$userId:$questionId";
  }

  QuestionRatingSummary? cached(String questionId) =>
      _cache[_cacheKey(questionId)];

  void clear() => _cache.clear();

  /// Yerel demo/tohum sorularında puanlama API'si yok.
  static bool canRate(String questionId) {
    final id = questionId.trim();
    if (id.isEmpty) return false;
    return !RegExp(r'^q_(tr|mat)_\d+$').hasMatch(id);
  }

  Future<QuestionRatingSummary> load(String questionId) async {
    final auth = AuthService.instance;
    if (!auth.isSignedIn) {
      throw const QuestionRatingException('Puanlamak için giriş yapın.');
    }
    if (auth.isAnonymous) {
      throw const QuestionRatingException(
        'Puanlamak için Google ile giriş yapın.',
      );
    }
    final response = await http
        .get(
          ApiConfig.questionRatingUri(questionId),
          headers: auth.authHeaders,
        )
        .timeout(const Duration(seconds: 10));
    return _decode(questionId, response);
  }

  Future<QuestionRatingSummary> rate(String questionId, int stars) async {
    if (stars < 1 || stars > 5) {
      throw const QuestionRatingException('Yıldız 1–5 arasında olmalı.');
    }
    final auth = AuthService.instance;
    if (!auth.isSignedIn) {
      throw const QuestionRatingException('Puanlamak için giriş yapın.');
    }
    if (auth.isAnonymous) {
      throw const QuestionRatingException(
        'Puanlamak için Google ile giriş yapın.',
      );
    }
    final response = await http
        .put(
          ApiConfig.questionRatingUri(questionId),
          headers: {
            ...auth.authHeaders,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'stars': stars}),
        )
        .timeout(const Duration(seconds: 10));
    return _decode(questionId, response);
  }

  QuestionRatingSummary _decode(String questionId, http.Response response) {
    if (response.statusCode != 200) {
      var message = 'Puan kaydedilemedi.';
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
      throw QuestionRatingException(message);
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map) {
      throw const QuestionRatingException('Geçersiz sunucu yanıtı.');
    }
    final summary = QuestionRatingSummary.fromJson(
      Map<String, dynamic>.from(body),
    );
    _cache[_cacheKey(questionId)] = summary;
    return summary;
  }
}
