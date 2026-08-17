import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/kpss_curriculum.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';

enum LastStudyKind { topic, smartReview, wrongNotebook, quiz }

/// Uygulama açılışında “kaldığın yerden devam” için son çalışma oturumu.
class LastStudySession {
  final LastStudyKind kind;
  final KpssType kpssType;
  final String? subjectId;
  final String? topicId;
  final String? testId;
  final String title;
  final String? subtitle;
  final DateTime updatedAt;
  final List<String> questionIds;
  final List<String?> answers;
  final int currentIndex;
  final int timeLimitMinutes;
  final int elapsedSeconds;

  const LastStudySession({
    required this.kind,
    required this.kpssType,
    this.subjectId,
    this.topicId,
    this.testId,
    required this.title,
    this.subtitle,
    required this.updatedAt,
    this.questionIds = const [],
    this.answers = const [],
    this.currentIndex = 0,
    this.timeLimitMinutes = 0,
    this.elapsedSeconds = 0,
  });

  bool get hasQuizProgress =>
      kind == LastStudyKind.quiz &&
      questionIds.isNotEmpty &&
      answers.length == questionIds.length;

  String get progressLabel {
    if (!hasQuizProgress) return subtitle ?? '';
    return 'Soru ${currentIndex + 1}/${questionIds.length}';
  }

  /// Devam panelinde gösterilecek test adı (testId üzerinden).
  String get testDisplayName {
    if (testId == null) return title;
    final test = ContentBankService.instance.testById(testId!);
    return test?.title ?? title;
  }

  String? get subjectName {
    if (subjectId == null) return null;
    return KpssCurriculum.findSubject(kpssType, subjectId!)?.name;
  }

  String? get topicName {
    if (topicId == null) return null;
    return KpssCurriculum.findTopic(kpssType, topicId!)?.name;
  }

  double get quizProgressFraction {
    if (!hasQuizProgress || questionIds.isEmpty) return 0;
    return ((currentIndex + 1) / questionIds.length).clamp(0.0, 1.0);
  }

  bool get isValid {
    switch (kind) {
      case LastStudyKind.topic:
        if (topicId == null || subjectId == null) return false;
        return KpssCurriculum.findTopic(kpssType, topicId!) != null &&
            KpssCurriculum.findSubject(kpssType, subjectId!) != null;
      case LastStudyKind.smartReview:
      case LastStudyKind.wrongNotebook:
        return true;
      case LastStudyKind.quiz:
        if (!hasQuizProgress || testId == null) return false;
        final bank = ContentBankService.instance;
        final test = bank.testById(testId!);
        if (test == null || !test.published) return false;
        final loaded = bank.questionsByIds(questionIds);
        return loaded.length == questionIds.length;
    }
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'kpssType': kpssType.name,
        'subjectId': subjectId,
        'topicId': topicId,
        'testId': testId,
        'title': title,
        'subtitle': subtitle,
        'updatedAt': updatedAt.toIso8601String(),
        'questionIds': questionIds,
        'answers': answers.map((a) => a ?? '').toList(),
        'currentIndex': currentIndex,
        'timeLimitMinutes': timeLimitMinutes,
        'elapsedSeconds': elapsedSeconds,
      };

  factory LastStudySession.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? 'topic';
    final typeName = json['kpssType'] as String? ?? 'lisans';
    final rawAnswers = (json['answers'] as List<dynamic>?) ?? const [];
    return LastStudySession(
      kind: LastStudyKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => LastStudyKind.topic,
      ),
      kpssType: KpssType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => KpssType.lisans,
      ),
      subjectId: json['subjectId'] as String?,
      topicId: json['topicId'] as String?,
      testId: json['testId'] as String?,
      title: json['title'] as String? ?? 'Çalışmaya devam et',
      subtitle: json['subtitle'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      questionIds: (json['questionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      answers: rawAnswers
          .map((e) {
            final s = e as String? ?? '';
            return s.isEmpty ? null : s;
          })
          .toList(),
      currentIndex: json['currentIndex'] as int? ?? 0,
      timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 0,
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
    );
  }
}

/// QuizScreen'e geçirilen devam bağlamı.
class QuizResumeMeta {
  final String testId;
  final KpssType kpssType;
  final String subjectId;
  final String topicId;

  const QuizResumeMeta({
    required this.testId,
    required this.kpssType,
    required this.subjectId,
    required this.topicId,
  });
}

class LastStudySessionService extends ChangeNotifier {
  LastStudySessionService._();
  static final LastStudySessionService instance = LastStudySessionService._();

  static const storageKey = 'last_study_session_v1';

  LastStudySession? _session;
  bool _initialized = false;
  /// clearQuizProgress sonrası geç gelen recordQuizProgress yazmalarını iptal eder.
  int _quizWriteEpoch = 0;

  bool get isInitialized => _initialized;

  /// Yalnızca yarım kalan test — konu gezintisi devam kartına yazılmaz.
  static bool isContinuableKind(LastStudyKind kind) =>
      kind == LastStudyKind.quiz;

  LastStudySession? get session {
    final s = _session;
    if (s == null || !s.isValid || !isContinuableKind(s.kind)) return null;
    return s;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _session = LastStudySession.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        if (_session != null &&
            (!_session!.isValid || !isContinuableKind(_session!.kind))) {
          _session = null;
          await prefs.remove(storageKey);
        }
      } catch (e) {
        debugPrint('LastStudySession load error: $e');
        _session = null;
        await prefs.remove(storageKey);
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> recordTopic({
    required KpssType kpssType,
    required String subjectId,
    required String topicId,
  }) async {
    // Konu açmak devam kartına yazılmaz; yalnızca yarım test kaydı tutulur.
  }

  Future<void> recordSmartReview(KpssType kpssType) async {
    // Akıllı tekrar ekranı — yarım test değil; devam kartına yazılmaz.
  }

  Future<void> recordWrongNotebook() async {
    // Yanlış defteri gezinme oturumu — “kaldığın yerden devam”a yazılmaz.
  }

  Future<void> recordQuizProgress({
    required QuizResumeMeta meta,
    required String title,
    required List<String> questionIds,
    required List<String?> answers,
    required int currentIndex,
    required int timeLimitMinutes,
    required Duration elapsed,
  }) async {
    if (questionIds.isEmpty || answers.length != questionIds.length) return;

    final epoch = _quizWriteEpoch;
    final subject = KpssCurriculum.findSubject(meta.kpssType, meta.subjectId);
    final topic = KpssCurriculum.findTopic(meta.kpssType, meta.topicId);
    final test = ContentBankService.instance.testById(meta.testId);
    final safeIndex = currentIndex.clamp(0, questionIds.length - 1);

    final next = LastStudySession(
      kind: LastStudyKind.quiz,
      kpssType: meta.kpssType,
      subjectId: meta.subjectId,
      topicId: meta.topicId,
      testId: meta.testId,
      title: test?.title ?? title,
      subtitle: subject != null && topic != null
          ? '${subject.name} · ${topic.name}'
          : topic?.name ?? subject?.name,
      updatedAt: DateTime.now(),
      questionIds: List<String>.from(questionIds),
      answers: List<String?>.from(answers),
      currentIndex: safeIndex,
      timeLimitMinutes: timeLimitMinutes,
      elapsedSeconds: elapsed.inSeconds.clamp(0, 7 * 24 * 3600),
    );
    // Test bitince clearQuizProgress çağrıldıysa bu yazmayı yok say.
    if (epoch != _quizWriteEpoch) return;
    _session = next;
    await _persist();
    if (epoch != _quizWriteEpoch) {
      // Clear yarışta kazandı; quiz'i geri yazmış olabiliriz.
      if (_session?.kind == LastStudyKind.quiz) {
        _session = null;
        await _persist();
        notifyListeners();
      }
      return;
    }
    notifyListeners();
  }

  /// Tamamlanan quiz'i (ve varsa devam kartını) tamamen kaldırır.
  Future<void> clearQuizProgress() async {
    await clear();
  }

  Future<void> clear() async {
    _quizWriteEpoch++;
    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    notifyListeners();
  }

  String relativeLabel([DateTime? at]) {
    final when = at ?? _session?.updatedAt;
    if (when == null) return '';
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${when.day}.${when.month}.${when.year}';
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_session == null) {
      await prefs.remove(storageKey);
      return;
    }
    await prefs.setString(storageKey, jsonEncode(_session!.toJson()));
  }
}
