import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Tamamlanan yayınlı konu testlerinin cevaplarını zorluk hesabına yollar.
class QuestionAttemptService {
  QuestionAttemptService._();
  static final QuestionAttemptService instance = QuestionAttemptService._();

  Future<QuestionAttemptSummary?> submitQuestion({
    required String testId,
    required String questionId,
    required String selectedOption,
  }) async {
    final auth = AuthService.instance;
    if (!auth.hasPermanentAccount ||
        testId.isEmpty ||
        questionId.isEmpty ||
        !RegExp(r'^[A-E]$').hasMatch(selectedOption)) {
      return null;
    }
    try {
      final response = await http
          .post(
            ApiConfig.questionAttemptUri(questionId),
            headers: {
              ...auth.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'testId': testId,
              'selectedOption': selectedOption,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      return QuestionAttemptSummary.fromJson(
          Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> submit({
    required String testId,
    required List<String> questionIds,
    required List<String?> selectedAnswers,
    Set<String> excludeQuestionIds = const {},
  }) async {
    final auth = AuthService.instance;
    if (!auth.hasPermanentAccount ||
        testId.isEmpty ||
        questionIds.length != selectedAnswers.length) {
      return;
    }

    final answers = <String, String>{};
    for (var index = 0; index < questionIds.length; index++) {
      final questionId = questionIds[index];
      if (excludeQuestionIds.contains(questionId)) continue;
      final selected = selectedAnswers[index]?.trim().toUpperCase() ?? '';
      if (selected.isNotEmpty) answers[questionId] = selected;
    }
    if (answers.isEmpty) return;

    try {
      await http
          .post(
            ApiConfig.testAttemptUri(testId),
            headers: {
              ...auth.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'answers': answers,
              'completed': true,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // İstatistik gönderimi, tamamlanan testi kullanıcı için başarısız yapmaz.
    }
  }
}

class QuestionAttemptSummary {
  final int attemptCount;
  final int solvedCount;
  final Map<String, double>? optionPercentages;

  const QuestionAttemptSummary({
    required this.attemptCount,
    required this.solvedCount,
    required this.optionPercentages,
  });

  factory QuestionAttemptSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['optionPercentages'];
    return QuestionAttemptSummary(
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      solvedCount: (json['solvedCount'] as num?)?.toInt() ?? 0,
      optionPercentages: raw is Map
          ? raw.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num).toDouble(),
              ),
            )
          : null,
    );
  }
}
