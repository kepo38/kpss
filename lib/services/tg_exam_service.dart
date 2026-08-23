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

class TgExamSubmitResult {
  final TgExamModel? exam;
  final String? error;

  const TgExamSubmitResult({this.exam, this.error});

  bool get ok => exam != null;
}

class TgExamQuestionsResult {
  final List<QuestionModel> questions;
  final TgExamQuestionsPayload? meta;
  final String? error;

  const TgExamQuestionsResult({
    this.questions = const [],
    this.meta,
    this.error,
  });

  bool get ok => questions.isNotEmpty;
}

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

  /// Aktif penceredeki ilk yayınlı TG deneme (baloncuk / kısayol).
  /// Kullanıcı zaten gönderdiyse gösterilmez.
  TgExamModel? get liveExam {
    for (final exam in _exams) {
      if (exam.isLiveNow && !exam.hasSubmittedAttempt) return exam;
    }
    return null;
  }

  Future<void> initialize({KpssType? kpssType}) async {
    if (kpssType != null) _kpssType = kpssType;
    _initialized = true;
    notifyListeners();
    await refresh();
  }

  Future<void> setKpssType(KpssType type) async {
    if (_kpssType == type) return;
    _kpssType = type;
    notifyListeners();
    // TG listesi tüm tipleri gösterir; tip değişince yeniden çekmeye gerek yok.
  }

  TgExamModel? examById(int id) {
    for (final exam in _exams) {
      if (exam.id == id) return exam;
    }
    return null;
  }

  /// Kullanıcının o an açık tuttuğu TG deneme ekranı — aynı denemenin
  /// duyuru bildirimi ön planda tekrar gösterilmesin.
  int? _visibleExamId;
  int? get visibleExamId => _visibleExamId;

  void setVisibleExam(int id) {
    _visibleExamId = id;
  }

  void clearVisibleExam(int id) {
    if (_visibleExamId == id) _visibleExamId = null;
  }

  Future<void> refresh() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      final response = await http
          .get(
            // KPSS tipinden bağımsız — tüm yayınlı TG denemeleri.
            ApiConfig.tgExamsUri(),
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

  Future<TgExamQuestionsResult> fetchQuestions(int examId) async {
    try {
      final response = await http
          .get(
            ApiConfig.tgExamQuestionsUri(examId),
            headers: AuthService.instance.authHeaders,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return TgExamQuestionsResult(
          error: _questionsErrorMessage(response.statusCode, response.bodyBytes),
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final meta = TgExamQuestionsPayload.fromJson(body);
      final parsed = QuestionFetchService.instance.parseQuestionsList(
        body['questions'],
      );
      if (parsed.isNotEmpty) {
        return TgExamQuestionsResult(
          questions: QuestionModel.forTgExamDisplayList(parsed),
          meta: meta,
        );
      }
      if (meta.questionIds.isNotEmpty) {
        final fetched = await QuestionFetchService.instance.fetchByIds(
          meta.questionIds,
        );
        if (fetched.isNotEmpty) {
          return TgExamQuestionsResult(
            questions: QuestionModel.forTgExamDisplayList(fetched),
            meta: meta,
          );
        }
      }
      return const TgExamQuestionsResult(
        error: 'Deneme soruları sunucudan alınamadı veya yayında değil.',
      );
    } catch (e) {
      debugPrint('TgExamService.fetchQuestions: $e');
      return const TgExamQuestionsResult(
        error: 'Bağlantı hatası — sorular yüklenemedi. Tekrar deneyin.',
      );
    }
  }

  String _questionsErrorMessage(int statusCode, List<int> bodyBytes) {
    String detail = '';
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        detail = '${decoded['detail']}'.trim();
      }
    } catch (_) {
      // ignore
    }
    if (detail.isNotEmpty) return detail;
    switch (statusCode) {
      case 401:
        return 'Oturum gerekli. Çıkış yapıp Google ile tekrar giriş yapın.';
      case 403:
        return 'Deneme katılım süresi sona erdi, henüz başlamadı veya Google girişi gerekli.';
      case 409:
        return 'Deneme zaten gönderildi veya sorular henüz tanımlanmadı.';
      default:
        return 'Sorular yüklenemedi (HTTP $statusCode).';
    }
  }

  Future<bool> saveProgress({
    required int examId,
    required Map<String, String?> answers,
    required int currentIndex,
    required Duration elapsed,
  }) async {
    if (!AuthService.instance.isSignedIn) return false;
    final payload = <String, String>{};
    answers.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        payload[key] = value;
      }
    });
    try {
      final response = await http
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
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final body = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          final model = TgExamModel.fromJson(body);
          _upsertLocal(model);
          notifyListeners();
        } catch (e) {
          debugPrint('TgExamService.saveProgress parse: $e');
        }
        return true;
      }
      debugPrint(
        'TgExamService.saveProgress: HTTP ${response.statusCode}',
      );
      return false;
    } catch (e) {
      debugPrint('TgExamService.saveProgress: $e');
      return false;
    }
  }

  Future<TgExamSubmitResult> submit({
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
        return TgExamSubmitResult(exam: model);
      }
      return TgExamSubmitResult(
        error: _submitErrorMessage(response.statusCode, response.bodyBytes),
      );
    } catch (e) {
      debugPrint('TgExamService.submit: $e');
      return const TgExamSubmitResult(
        error: 'Bağlantı hatası — cevaplar gönderilemedi. Tekrar deneyin.',
      );
    }
  }

  String _submitErrorMessage(int statusCode, List<int> bodyBytes) {
    String detail = '';
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        detail = '${decoded['detail']}'.trim();
      }
    } catch (_) {
      // ignore
    }
    if (detail.isNotEmpty) return detail;
    switch (statusCode) {
      case 403:
        return 'Deneme katılım süresi sona erdi veya henüz başlamadı.';
      case 409:
        return 'Deneme zaten gönderilmiş.';
      default:
        return 'Cevaplar gönderilemedi (HTTP $statusCode).';
    }
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
Future<bool> tgExamOnProgress({
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
  return TgExamService.instance.saveProgress(
    examId: examId,
    answers: map,
    currentIndex: currentIndex,
    elapsed: elapsed,
  );
}

Future<TgExamSubmitResult> submitTgExamFromQuiz({
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
