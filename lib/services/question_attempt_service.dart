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

  /// Tamamlanan testi sunucuya yazar; [TopicTestCompletion] hata bildirimi kotası için gerekir.
  Future<bool> submit({
    required String testId,
    required List<String> questionIds,
    required List<String?> selectedAnswers,
    Set<String> excludeQuestionIds = const {},
    bool completionOnly = false,
  }) async {
    final auth = AuthService.instance;
    if (!auth.hasPermanentAccount || testId.isEmpty) return false;
    if (!completionOnly &&
        questionIds.length != selectedAnswers.length) {
      return false;
    }

    final answers = <String, String>{};
    if (!completionOnly) {
      for (var index = 0; index < questionIds.length; index++) {
        final questionId = questionIds[index];
        if (excludeQuestionIds.contains(questionId)) continue;
        final selected = selectedAnswers[index]?.trim().toUpperCase() ?? '';
        if (selected.isNotEmpty) answers[questionId] = selected;
      }
      if (answers.isEmpty) return false;
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http
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
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) return true;
      } catch (_) {
        if (attempt == 1) return false;
      }
    }
    return false;
  }

  /// Yerelde bitmiş testlerin tamamlanma kaydını sunucuya yansıtır (cevaplar olmadan).
  Future<bool> markTestCompleted(String testId) {
    return submit(
      testId: testId,
      questionIds: const [],
      selectedAnswers: const [],
      completionOnly: true,
    );
  }
}

class QuestionAttemptSummary {
  final int attemptCount;
  final int solvedCount;
  final double? correctRate;
  final Map<String, double>? optionPercentages;

  const QuestionAttemptSummary({
    required this.attemptCount,
    required this.solvedCount,
    this.correctRate,
    required this.optionPercentages,
  });

  factory QuestionAttemptSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['optionPercentages'];
    return QuestionAttemptSummary(
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      solvedCount: (json['solvedCount'] as num?)?.toInt() ?? 0,
      correctRate: (json['correctRate'] as num?)?.toDouble(),
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
