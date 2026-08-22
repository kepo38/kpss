import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../models/tg_exam_models.dart';
import '../widgets/countdown_widget.dart';
import 'auth_service.dart';
import 'question_fetch_service.dart';

/// Türkiye Geneli denemeler — liste, oturum, gönderim.
class TgExamService extends ChangeNotifier {
  TgExamService._();
  static final TgExamService instance = TgExamService._();

  bool _initialized = false;
  KpssType _kpssType = KpssType.lisans;
  List<TgExamModel> _exams = const [];
  bool _loading = false;
  String? _lastError;

  bool get isInitialized => _initialized;
  KpssType get kpssType => _kpssType;
  List<TgExamModel> get exams => List.unmodifiable(_exams);
  bool get loading => _loading;
  String? get lastError => _lastError;

  Future<void> initialize({KpssType? kpssType}) async {
    if (kpssType != null) _kpssType = kpssType;
    _initialized = true;
    notifyListeners();
    await refresh();
  }

  Future<void> setKpssType(KpssType type) async {
    if (_kpssType == type && _initialized) return;
    _kpssType = type;
    await refresh();
  }

  TgExamModel? examById(int id) {
    for (final exam in _exams) {
      if (exam.id == id) return exam;
    }
    return null;
  }

  Future<void> refresh() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            ApiConfig.tgExamsUri(kpssType: _kpssType.apiValue),
            headers: AuthService.instance.authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final raw = body['exams'];
        _exams = raw is List
            ? raw
                .whereType<Map>()
                .map(
                  (item) => TgExamModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
            : const [];
      } else {
        _lastError = 'TG denemeleri yüklenemedi (${response.statusCode}).';
      }
    } catch (e) {
      debugPrint('TgExamService.refresh: $e');
      _lastError = 'Bağlantı hatası — TG denemeleri alınamadı.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<TgExamModel?> fetchDetail(int examId) async {
    try {
      final response = await http
          .get(
            ApiConfig.tgExamDetailUri(examId),
            headers: AuthService.instance.authHeaders,
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final model = TgExamModel.fromJson(body);
      _upsertLocal(model);
      notifyListeners();
      return model;
    } catch (e) {
      debugPrint('TgExamService.fetchDetail: $e');
      return examById(examId);
    }
  }

  Future<({List<QuestionModel> questions, TgExamQuestionsPayload meta})?>
      fetchQuestions(int examId) async {
    try {
      final response = await http
          .get(
            ApiConfig.tgExamQuestionsUri(examId),
            headers: AuthService.instance.authHeaders,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final meta = TgExamQuestionsPayload.fromJson(body);
      final parsed = QuestionFetchService.instance.parseQuestionsList(
        body['questions'],
      );
      if (parsed.isNotEmpty) {
        return (
          questions: QuestionModel.forTgExamDisplayList(parsed),
          meta: meta,
        );
      }
      if (meta.questionIds.isNotEmpty) {
        final fetched = await QuestionFetchService.instance.fetchByIds(
          meta.questionIds,
        );
        return (
          questions: QuestionModel.forTgExamDisplayList(fetched),
          meta: meta,
        );
      }
      return (questions: const <QuestionModel>[], meta: meta);
    } catch (e) {
      debugPrint('TgExamService.fetchQuestions: $e');
      return null;
    }
  }

  Future<void> saveProgress({
    required int examId,
    required Map<String, String?> answers,
    required int currentIndex,
    required Duration elapsed,
  }) async {
    if (!AuthService.instance.isSignedIn) return;
    final payload = <String, String>{};
    answers.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        payload[key] = value;
      }
    });
    try {
      await http
          .post(
            ApiConfig.tgExamProgressUri(examId),
            headers: {
              ...AuthService.instance.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'answers': payload,
              'currentIndex': currentIndex,
              'elapsedSeconds': elapsed.inSeconds,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('TgExamService.saveProgress: $e');
    }
  }

  Future<TgExamModel?> submit({
    required int examId,
    required List<QuestionModel> questions,
    required List<String?> answers,
    required Duration duration,
  }) async {
    final payload = <String, String>{};
    for (var i = 0; i < questions.length; i++) {
      final selected = answers[i];
      if (selected != null && selected.isNotEmpty) {
        payload[questions[i].id] = selected;
      }
    }
    try {
      final response = await http
          .post(
            ApiConfig.tgExamSubmitUri(examId),
            headers: {
              ...AuthService.instance.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'answers': payload,
              'durationSeconds': duration.inSeconds,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final model = TgExamModel.fromJson(body);
        _upsertLocal(model);
        notifyListeners();
        return model;
      }
    } catch (e) {
      debugPrint('TgExamService.submit: $e');
    }
    return null;
  }

  List<String?> initialAnswersFor(TgExamModel exam, List<String> questionIds) {
    final attempt = exam.myAttempt;
    if (attempt == null || attempt.isSubmitted) {
      return List<String?>.filled(questionIds.length, null);
    }
    return questionIds
        .map((id) {
          final raw = attempt.answers[id];
          return raw == null || raw.isEmpty ? null : raw;
        })
        .toList(growable: false);
  }

  void _upsertLocal(TgExamModel model) {
    final list = List<TgExamModel>.from(_exams);
    final index = list.indexWhere((e) => e.id == model.id);
    if (index >= 0) {
      list[index] = model;
    } else {
      list.insert(0, model);
    }
    _exams = list;
  }
}

extension on KpssType {
  String get apiValue {
    switch (this) {
      case KpssType.lisans:
        return 'lisans';
      case KpssType.onLisans:
        return 'onLisans';
      case KpssType.ortaogretim:
        return 'ortaogretim';
    }
  }
}

/// QuizScreen.onProgress için TG deneme kaydı.
Future<void> tgExamOnProgress({
  required int examId,
  required List<QuestionModel> questions,
  required List<String?> answers,
  required int currentIndex,
  required Duration elapsed,
}) async {
  final map = <String, String?>{};
  for (var i = 0; i < questions.length; i++) {
    map[questions[i].id] = answers[i];
  }
  await TgExamService.instance.saveProgress(
    examId: examId,
    answers: map,
    currentIndex: currentIndex,
    elapsed: elapsed,
  );
}

Future<TgExamModel?> submitTgExamFromQuiz({
  required int examId,
  required QuizResult result,
  required List<QuestionModel> questions,
}) async {
  return TgExamService.instance.submit(
    examId: examId,
    questions: questions,
    answers: result.selectedAnswers,
    duration: result.duration,
  );
}
