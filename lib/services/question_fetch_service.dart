import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/content_models.dart';
import '../models/question_model.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';
import 'offline_pack_service.dart';

class QuestionFetchResult {
  final List<QuestionModel> questions;
  final String? errorMessage;

  const QuestionFetchResult({
    required this.questions,
    this.errorMessage,
  });

  bool get isEmpty => questions.isEmpty;
}

/// Bulut tabanlı soru çekme — test başında yalnızca gerekli sorular indirilir.
class QuestionFetchService {
  QuestionFetchService._();
  static final QuestionFetchService instance = QuestionFetchService._();

  final Map<String, QuestionModel> _sessionCache = {};

  /// Yerel tam paket (offline premium) varsa oradan, yoksa API + yedekler.
  Future<QuestionFetchResult> fetchForTest(TopicTestModel test) async {
    final local = ContentBankService.instance.questionsForTest(test);
    if (_useLocalFullBank && local.isNotEmpty) {
      return QuestionFetchResult(questions: local);
    }

    final backendId = _backendTestId(test.id);
    String? errorMessage;
    List<QuestionModel> fromApi = const [];

    try {
      final response = await http
          .get(
            ApiConfig.testQuestionsUri(backendId),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        fromApi = _parseQuestions(body['questions']);
        _rememberSession(fromApi);
      } else if (response.statusCode == 404) {
        errorMessage = 'Test bulunamadı ($backendId).';
      } else {
        errorMessage = 'Sunucu hatası (${response.statusCode}).';
      }
    } catch (e) {
      debugPrint('Test questions fetch ($backendId): $e');
      errorMessage =
          'Sunucuya ulaşılamadı (${ApiConfig.baseUrl}). '
          'Telefon ve bilgisayar aynı Wi‑Fi\'de olmalı.';
    }

    final ordered = _resolveOrder(fromApi, test);
    if (ordered.isNotEmpty) {
      return QuestionFetchResult(questions: ordered);
    }

    if (local.isNotEmpty) {
      return QuestionFetchResult(questions: local);
    }

    if (test.questionIds.isNotEmpty) {
      final byIds = await fetchByIds(test.questionIds);
      if (byIds.isNotEmpty) {
        return QuestionFetchResult(questions: byIds);
      }
    }

    if (fromApi.isNotEmpty) {
      return QuestionFetchResult(questions: fromApi);
    }

    return QuestionFetchResult(
      questions: const [],
      errorMessage: errorMessage ??
          'Bu testte soru bulunamadı. Panelde soruların yayında '
          'olduğundan emin olun.',
    );
  }

  Future<List<QuestionModel>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];

    final unique = ids.toSet().toList();
    final results = <QuestionModel>[];
    final missing = <String>[];

    for (final id in unique) {
      final cached =
          _sessionCache[id] ?? ContentBankService.instance.questionById(id);
      if (cached != null) {
        results.add(cached);
      } else {
        missing.add(id);
      }
    }

    if (missing.isNotEmpty) {
      final fetched = await _fetchIdsFromApi(missing);
      _rememberSession(fetched);
      results.addAll(fetched);
    }

    return QuestionModel.keepGroupsContiguous(_orderByIds(results, ids));
  }

  Future<List<QuestionModel>> fetchSimilar(
    String questionId, {
    int limit = 5,
  }) async {
    try {
      final response = await http
          .get(
            ApiConfig.similarQuestionsUri(questionId, limit: limit),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map) return const [];
      final parsed = _parseQuestions(body['questions']);
      _rememberSession(parsed);
      return parsed;
    } catch (e) {
      debugPrint('Similar questions fetch ($questionId): $e');
      return const [];
    }
  }

  List<QuestionModel> parseQuestionsList(Object? raw) => _parseQuestions(raw);

  List<QuestionModel> _parseQuestions(Object? raw) {
    if (raw is! List) return const [];
    final parsed = <QuestionModel>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        parsed.add(
          QuestionModel.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (e) {
        debugPrint('Question JSON parse error: $e');
      }
    }
    return parsed;
  }

  List<QuestionModel> _resolveOrder(
    List<QuestionModel> questions,
    TopicTestModel test,
  ) {
    if (questions.isEmpty) return const [];
    if (test.questionIds.isEmpty) {
      return QuestionModel.interleaveOsymSordu(
        QuestionModel.keepGroupsContiguous(questions),
      );
    }
    final ordered = _orderByIds(questions, test.questionIds);
    final contiguous = QuestionModel.keepGroupsContiguous(
      ordered.isNotEmpty ? ordered : questions,
    );
    final laidOut = QuestionModel.interleaveOsymSordu(
      contiguous.isNotEmpty ? contiguous : questions,
    );
    return laidOut.isNotEmpty ? laidOut : questions;
  }

  Future<List<QuestionModel>> _fetchIdsFromApi(List<String> ids) async {
    try {
      final response = await http
          .get(
            ApiConfig.questionsByIdsUri(ids),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! List) return const [];
      return _parseQuestions(body);
    } catch (e) {
      debugPrint('Questions by ids fetch: $e');
      return const [];
    }
  }

  bool get _useLocalFullBank =>
      OfflinePackService.instance.isReady &&
      ContentBankService.instance.hasFullQuestionBank;

  void _rememberSession(List<QuestionModel> questions) {
    for (final q in questions) {
      _sessionCache[q.id] = q;
    }
    ContentBankService.instance.mergeSessionQuestions(questions);
  }

  List<QuestionModel> _orderByIds(
    List<QuestionModel> questions,
    Iterable<String> ids,
  ) {
    final byId = {for (final q in questions) q.id: q};
    return ids.map((id) => byId[id]).whereType<QuestionModel>().toList();
  }

  String _backendTestId(String localTestId) {
    for (final type in KpssType.values) {
      final suffix = '_${type.name}';
      if (localTestId.endsWith(suffix)) {
        return localTestId.substring(0, localTestId.length - suffix.length);
      }
    }
    return localTestId;
  }
}
