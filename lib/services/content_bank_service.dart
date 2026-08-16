import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/daily_mini_exam_constants.dart';
import '../constants/savings_constants.dart';
import '../data/kpss_curriculum.dart';
import '../models/content_models.dart';
import '../models/question_model.dart';
import '../utils/daily_mission_copy.dart';
import '../widgets/countdown_widget.dart';
import 'user_savings_insight_service.dart';

/// Öğrenci tarafı soru bankası, konu testleri ve istatistikler.
/// İçerik üretimi Django web panelindedir; mobil yalnızca yayın paketini okur.
class ContentBankService extends ChangeNotifier {
  ContentBankService._();
  static final ContentBankService instance = ContentBankService._();

  static const _kConfigs = 'content_topic_configs';
  static const _kTests = 'content_topic_tests';
  static const _kAttempts = 'content_test_attempts';
  static const _kSolvedQuestions = 'content_solved_question_ids';
  static const _kWrongQuestions = 'content_wrong_question_ids';
  static const _kQuestions = 'content_questions';
  static const _kLessons = 'content_lessons';
  static const _kPackVersion = 'content_pack_version';
  static const _kDailyAdBonuses = 'content_daily_ad_test_bonuses';
  static const _kCatalogSubjects = 'content_catalog_subjects';

  /// Ders başına günde en fazla kaç kez reklamla ek test hakkı kazanılır.
  static const dailyAdBonusPerSubject = 1;

  static const dailyFreeTestsPerSubject = 1;

  final Map<String, TopicTestConfig> _configs = {};
  final List<TopicTestModel> _tests = [];
  final List<TestAttemptModel> _attempts = [];
  final List<QuestionModel> _questions = [];
  final List<TopicLessonModel> _lessons = [];
  final Set<String> _solvedQuestionIds = {};
  final Set<String> _wrongQuestionIds = {};
  final Map<String, int> _dailyAdBonuses = {};
  int? _packVersion;
  bool _loaded = false;
  bool _fullQuestionBankPersisted = false;

  int? get packVersion => _packVersion;

  /// Test listesi ve müfredat yerelde var mı?
  bool get hasCachedCatalog =>
      _packVersion != null && _tests.isNotEmpty;

  /// Offline premium tam paket — tüm sorular yerelde.
  bool get hasFullQuestionBank =>
      _fullQuestionBankPersisted && _questions.isNotEmpty;

  /// Yerelde test çözmeye yetecek yayın paketi var mı?
  bool get hasCachedPack => hasCachedCatalog && hasFullQuestionBank;

  int get cachedQuestionCount => _questions.length;
  int get cachedTestCount => _tests.where((t) => t.published).length;

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _packVersion = prefs.getInt(_kPackVersion);

    final configsRaw = prefs.getString(_kConfigs);
    if (configsRaw != null) {
      final map = jsonDecode(configsRaw) as Map<String, dynamic>;
      for (final e in map.entries) {
        _configs[e.key] = TopicTestConfig.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        );
      }
    }

    final testsRaw = prefs.getString(_kTests);
    if (testsRaw != null) {
      final list = jsonDecode(testsRaw) as List<dynamic>;
      _tests
        ..clear()
        ..addAll(
          list.map(
            (e) => TopicTestModel.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    }

    final attemptsRaw = prefs.getString(_kAttempts);
    if (attemptsRaw != null) {
      final list = jsonDecode(attemptsRaw) as List<dynamic>;
      _attempts
        ..clear()
        ..addAll(
          list.map(
            (e) =>
                TestAttemptModel.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    }

    final solvedRaw = prefs.getString(_kSolvedQuestions);
    if (solvedRaw != null) {
      final list = jsonDecode(solvedRaw) as List<dynamic>;
      _solvedQuestionIds
        ..clear()
        ..addAll(list.map((e) => e.toString()));
    }

    final wrongRaw = prefs.getString(_kWrongQuestions);
    if (wrongRaw != null) {
      final list = jsonDecode(wrongRaw) as List<dynamic>;
      _wrongQuestionIds
        ..clear()
        ..addAll(list.map((e) => e.toString()));
    }

    _loadDailyAdBonuses(prefs.getString(_kDailyAdBonuses));

    final questionsRaw = prefs.getString(_kQuestions);
    if (questionsRaw != null) {
      final list = jsonDecode(questionsRaw) as List<dynamic>;
      _questions
        ..clear()
        ..addAll(
          list.map(
            (e) => QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    }

    final lessonsRaw = prefs.getString(_kLessons);
    if (lessonsRaw != null) {
      final list = jsonDecode(lessonsRaw) as List<dynamic>;
      _lessons
        ..clear()
        ..addAll(
          list.map(
            (e) =>
                TopicLessonModel.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    }

    if (_questions.isEmpty) {
      _seedSampleQuestions();
      _fullQuestionBankPersisted = false;
    } else {
      _fullQuestionBankPersisted = true;
    }
    if (_tests.isEmpty) {
      _seedSampleTests();
    }
    if (_lessons.isEmpty) {
      _seedSampleLessons();
    }

    KpssCurriculum.loadCatalogFromJsonString(
      prefs.getString(_kCatalogSubjects),
    );

    _loaded = true;
    if (_questions.isEmpty) {
      unawaited(_persistAll());
    }
  }

  /// Django hafif kataloğunu uygular — soru gövdeleri indirilmez.
  Future<void> applyCatalogPack(Map<String, dynamic> pack) async {
    await initialize();
    await _applyPackMetadata(pack);
    _questions.clear();
    _fullQuestionBankPersisted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQuestions);
    await _persistAll(skipQuestions: true);
    notifyListeners();
  }

  /// Django tam yayın paketini yerel cache'e uygular (offline premium).
  Future<void> applyPublishedPack(Map<String, dynamic> pack) async {
    await initialize();
    final parserQuestions = (pack['questions'] as List<dynamic>? ?? const [])
        .map(
          (e) => QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    await _applyPackMetadata(pack);

    _questions
      ..clear()
      ..addAll(parserQuestions);
    _fullQuestionBankPersisted = parserQuestions.isNotEmpty;

    await _persistAll();
    notifyListeners();
  }

  /// Oturum içi sorular — diske yazılmaz, yanlış defteri vb. için.
  void mergeSessionQuestions(Iterable<QuestionModel> questions) {
    for (final q in questions) {
      final idx = _questions.indexWhere((item) => item.id == q.id);
      if (idx >= 0) {
        _questions[idx] = q;
      } else {
        _questions.add(q);
      }
    }
  }

  Future<void> _applyPackMetadata(Map<String, dynamic> pack) async {
    final parserTests = <TopicTestModel>[];
    for (final raw in (pack['tests'] as List<dynamic>? ?? const [])) {
      final json = Map<String, dynamic>.from(raw as Map);
      for (final type in KpssType.values) {
        parserTests.add(
          TopicTestModel(
            id: '${json['id']}_${type.name}',
            topicId: json['topicId'] as String,
            kpssType: type,
            title: json['title'] as String,
            description: json['description'] as String?,
            questionCount: json['questionCount'] as int? ??
                ((json['questionIds'] as List?)?.length ?? 0),
            timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 0,
            questionIds: (json['questionIds'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                const [],
            createdAt: DateTime.parse(json['createdAt'] as String),
            published: json['published'] as bool? ?? true,
          ),
        );
      }
    }

    final subjectsRaw = pack['subjects'] as List<dynamic>? ?? const [];
    if (subjectsRaw.isNotEmpty) {
      KpssCurriculum.applyCatalogFromJson(subjectsRaw);
    }

    final parserConfigs = <String, TopicTestConfig>{};
    for (final s in subjectsRaw) {
      final subject = Map<String, dynamic>.from(s as Map);
      for (final t in (subject['topics'] as List<dynamic>? ?? const [])) {
        final topic = Map<String, dynamic>.from(t as Map);
        final topicId = topic['slug'] as String;
        for (final type in KpssType.values) {
          parserConfigs['${type.name}_$topicId'] = TopicTestConfig(
            topicId: topicId,
            kpssType: type,
            questionsPerTest: topic['questions_per_test'] as int? ?? 20,
            timeLimitMinutes: topic['time_limit_minutes'] as int? ?? 0,
            shuffleQuestions: topic['shuffle_questions'] as bool? ?? true,
            shuffleOptions: topic['shuffle_options'] as bool? ?? true,
            showSolutionAfterEach:
                topic['show_solution_after_each'] as bool? ?? false,
          );
        }
      }
    }

    final parserLessons = (pack['lessons'] as List<dynamic>? ?? const [])
        .map(
          (e) => TopicLessonModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    _tests
      ..clear()
      ..addAll(parserTests);
    if (parserConfigs.isNotEmpty) {
      _configs
        ..clear()
        ..addAll(parserConfigs);
    }
    _lessons
      ..clear()
      ..addAll(parserLessons);

    final version = pack['version'];
    if (version is int) {
      _packVersion = version;
    } else if (version is num) {
      _packVersion = version.toInt();
    }
    if (_packVersion != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPackVersion, _packVersion!);
    }
  }

  TopicTestConfig configFor(KpssType type, String topicId) {
    final key = '${type.name}_$topicId';
    final topic = KpssCurriculum.findTopic(type, topicId);
    return _configs[key] ??
        TopicTestConfig(
          topicId: topicId,
          kpssType: type,
          questionsPerTest:
              topic?.questionsPerTest ?? KpssCurriculum.defaultQuestionsPerTest,
        );
  }

  List<TopicTestModel> testsForTopic(KpssType type, String topicId) {
    return _tests
        .where((t) => t.kpssType == type && t.topicId == topicId && t.published)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  TopicTestModel? testById(String testId) {
    for (final t in _tests) {
      if (t.id == testId) return t;
    }
    return null;
  }

  List<TopicTestModel> allTests({KpssType? type}) {
    final list = type == null
        ? List<TopicTestModel>.from(_tests)
        : _tests.where((t) => t.kpssType == type).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<QuestionModel> questionsForTest(TopicTestModel test) {
    final byId = {for (final q in _questions) q.id: q};
    return test.questionIds
        .map((id) => byId[id])
        .whereType<QuestionModel>()
        .toList();
  }

  /// Paketteki meta sayı yerine gerçekten yüklenebilir soru adedi.
  int availableQuestionCount(TopicTestModel test) =>
      questionsForTest(test).length;

  /// Katalog meta — test.questionIds (bulutta gövde indirilmeden doğru sayı).
  int catalogQuestionCount(TopicTestModel test) {
    if (test.questionIds.isNotEmpty) return test.questionIds.length;
    if (test.questionCount > 0) return test.questionCount;
    return questionsForTest(test).length;
  }

  int catalogQuestionCountForTopic(KpssType type, String topicId) =>
      topicQuestionProgress(type, topicId).total;

  int catalogQuestionCountForSubject(KpssType type, String subjectId) =>
      catalogQuestionIdsForSubject(type, subjectId).length;

  QuestionModel? questionById(String id) {
    for (final q in _questions) {
      if (q.id == id) return q;
    }
    return null;
  }

  List<QuestionModel> questionsByIds(Iterable<String> ids) {
    final byId = {for (final q in _questions) q.id: q};
    return ids.map((id) => byId[id]).whereType<QuestionModel>().toList();
  }

  List<String> get allQuestionIds => _questions.map((q) => q.id).toList();

  /// Katalogdaki testlerden soru kimlikleri (bulut modda tam banka yokken).
  List<String> get catalogQuestionIds =>
      _tests.expand((t) => t.questionIds).toSet().toList()..sort();

  List<String> catalogQuestionIdsForTopic(KpssType type, String topicId) {
    return _tests
        .where((t) => t.kpssType == type && t.topicId == topicId)
        .expand((t) => t.questionIds)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> catalogQuestionIdsForSubject(KpssType type, String subjectId) {
    final subject = KpssCurriculum.findSubject(type, subjectId);
    if (subject == null) return const [];
    final topicIds = subject.topics.map((t) => t.id).toSet();
    return _tests
        .where((t) => t.kpssType == type && topicIds.contains(t.topicId))
        .expand((t) => t.questionIds)
        .toSet()
        .toList()
      ..sort();
  }

  /// Ders slug'ına göre yayınlanmış sorular (ders adı eşlemesi).
  List<QuestionModel> questionsForSubject(KpssType type, String subjectId) {
    final subject = KpssCurriculum.findSubject(type, subjectId);
    if (subject == null) return const [];
    final topicNames = subject.topics.map((t) => t.name).toSet();
    return _questions
        .where(
          (q) =>
              q.dersAdi == subject.name &&
              (topicNames.contains(q.konuAdi) || q.dersAdi == subject.name),
        )
        .toList();
  }

  /// Favori sorunun güncel testini bulur (soru başka teste taşınsa bile).
  TopicTestModel? testContainingQuestion(String questionId) {
    final matches = _tests
        .where((t) => t.published && t.questionIds.contains(questionId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.isEmpty ? null : matches.first;
  }

  List<TopicLessonModel> lessonsForTopic(String topicId) {
    return _lessons.where((l) => l.topicId == topicId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<QuestionModel> questionsForTopic(KpssType type, String topicId) {
    final topic = KpssCurriculum.findTopic(type, topicId);
    if (topic == null) return const [];
    final subject = KpssCurriculum.subjectsFor(type).firstWhere(
      (s) => s.topics.any((t) => t.id == topicId),
    );
    return _questions
        .where(
          (q) =>
              q.dersAdi == subject.name &&
              (q.konuAdi == topic.name ||
                  topic.subtopics.contains(q.altKonuAdi)),
        )
        .toList();
  }

  /// Ders altındaki yayınlanmış soru sayısı (uygulama paketi).
  int questionCountForSubject(String subjectName) {
    return _questions.where((q) => q.dersAdi == subjectName).length;
  }

  Future<void> recordAttempt(
    TestAttemptModel attempt, {
    List<String> questionIds = const [],
    List<String> wrongQuestionIds = const [],
  }) async {
    _attempts.add(attempt);
    final futures = <Future<void>>[_persistAttempts()];
    if (questionIds.isNotEmpty) {
      _solvedQuestionIds.addAll(questionIds);
      futures.add(_persistSolvedQuestions());
    }
    if (wrongQuestionIds.isNotEmpty) {
      _wrongQuestionIds.addAll(wrongQuestionIds);
      futures.add(_persistWrongQuestions());
    }
    await Future.wait(futures);
    notifyListeners();
    unawaited(UserSavingsInsightService.instance.handleTestCompleted());
  }

  /// Tasarruf hesabı ve istatistikler için salt okunur deneme listesi.
  List<TestAttemptModel> get allAttempts => List.unmodifiable(_attempts);

  /// Günün Mini Denemesi ödev barını ve günlük test hakkını tüketmez.
  @visibleForTesting
  static bool countsTowardDailyHomework(TestAttemptModel attempt) {
    return !attempt.testId.startsWith(DailyMiniExamConstants.testIdPrefix);
  }

  /// Bugün (yerel saat) bu derste tamamlanan konu testi sayısı.
  /// Lisans / Ön Lisans / Ortaöğretim müfredatı ortak — tip ayrımı yok.
  int dailyCompletedTestsForSubject(KpssType type, String subjectId) {
    final topicIds = KpssCurriculum.topicIdsForSubject(type, subjectId);
    if (topicIds.isEmpty) return 0;
    final now = DateTime.now();
    return _attempts.where((a) {
      if (!countsTowardDailyHomework(a)) return false;
      if (!topicIds.contains(a.topicId)) return false;
      final d = a.completedAt.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  /// Bugünkü 5 görev barı: kaç ders yeşil, hangileri kaldı.
  DailyMissionProgress dailyMissionProgress(KpssType type) {
    final subjects = KpssCurriculum.subjectsFor(type)
        .where((s) => SavingsConstants.missionSubjectIds.contains(s.id))
        .toList();
    final remaining = <String>[];
    var done = 0;
    for (final subject in subjects) {
      if (dailyCompletedTestsForSubject(type, subject.id) > 0) {
        done++;
      } else {
        remaining.add(subject.name);
      }
    }
    return DailyMissionProgress(
      done: done,
      total: subjects.length,
      remainingNames: remaining,
    );
  }

  /// Bugün reklamla kazanılan ek test hakkı (ders başına, tüm tipler).
  int dailyAdBonusTestsForSubject(KpssType type, String subjectId) {
    var best = 0;
    for (final t in KpssType.values) {
      final bonus = _dailyAdBonuses[_dailyBonusStorageKey(t, subjectId)] ?? 0;
      if (bonus > best) best = bonus;
    }
    return best;
  }

  /// Bugün bu derste kullanılabilir toplam test hakkı.
  int dailyTestAllowanceForSubject(KpssType type, String subjectId) {
    final bonuses = dailyAdBonusTestsForSubject(
      type,
      subjectId,
    ).clamp(0, dailyAdBonusPerSubject).toInt();
    return dailyFreeTestsPerSubject + bonuses;
  }

  /// Premium olmayan: ders başına günde 1 test (+ reklam bonusu).
  bool canStartDailySubjectTest(KpssType type, String subjectId) {
    return hasDailyTestQuota(
      completedTests: dailyCompletedTestsForSubject(type, subjectId),
      adBonusTests: dailyAdBonusTestsForSubject(type, subjectId),
    );
  }

  /// Günlük ücretsiz hak bittiyse reklam izleyerek +1 test kazanılabilir mi?
  bool canWatchAdForDailyTestBonus(KpssType type, String subjectId) {
    return canEarnDailyAdBonus(
      completedTests: dailyCompletedTestsForSubject(type, subjectId),
      adBonusTests: dailyAdBonusTestsForSubject(type, subjectId),
    );
  }

  @visibleForTesting
  static bool hasDailyTestQuota({
    required int completedTests,
    required int adBonusTests,
  }) {
    final bonuses = adBonusTests.clamp(0, dailyAdBonusPerSubject);
    return completedTests < dailyFreeTestsPerSubject + bonuses;
  }

  @visibleForTesting
  static bool canEarnDailyAdBonus({
    required int completedTests,
    required int adBonusTests,
  }) {
    return completedTests >= dailyFreeTestsPerSubject &&
        adBonusTests < dailyAdBonusPerSubject;
  }

  Future<void> grantAdBonusDailyTest(KpssType type, String subjectId) async {
    final key = _dailyBonusStorageKey(type, subjectId);
    final current = _dailyAdBonuses[key] ?? 0;
    if (current >= dailyAdBonusPerSubject) return;
    _dailyAdBonuses[key] = current + 1;
    await _persistDailyAdBonuses();
    notifyListeners();
  }

  @visibleForTesting
  static String dailyBonusStorageKeyFor(
    KpssType type,
    String subjectId,
    DateTime day,
  ) {
    final local = day.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final dayPart = local.day.toString().padLeft(2, '0');
    return '${type.name}_${subjectId}_${local.year}-$month-$dayPart';
  }

  String _dailyBonusStorageKey(KpssType type, String subjectId) {
    return dailyBonusStorageKeyFor(type, subjectId, DateTime.now());
  }

  void _loadDailyAdBonuses(String? raw) {
    _dailyAdBonuses.clear();
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final todayKeySuffix = _todayKeySuffix();
    for (final entry in map.entries) {
      if (!entry.key.endsWith(todayKeySuffix)) continue;
      _dailyAdBonuses[entry.key] = (entry.value as num).toInt();
    }
  }

  String _todayKeySuffix() {
    final now = DateTime.now().toLocal();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _persistDailyAdBonuses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kDailyAdBonuses,
      jsonEncode(_dailyAdBonuses),
    );
  }

  List<TestAttemptModel> attemptsForType(KpssType type) {
    return _attempts.where((a) => a.kpssType == type).toList();
  }

  Set<String> get wrongQuestionIds => Set.unmodifiable(_wrongQuestionIds);

  int get wrongQuestionCount => _wrongQuestionIds.length;

  /// En çok yanlış yapılan konular (ders · konu, adet).
  List<(String topicLabel, int count)> wrongTopicsSummary({int limit = 3}) {
    final counts = <String, int>{};
    for (final id in _wrongQuestionIds) {
      final q = questionById(id);
      if (q == null) continue;
      final label = '${q.dersAdi} · ${q.konuAdi}';
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => (e.key, e.value)).toList();
  }

  Future<void> removeWrongQuestion(String questionId) async {
    if (!_wrongQuestionIds.remove(questionId)) return;
    await _persistWrongQuestions();
    notifyListeners();
  }

  /// Yanlış listesine ekle; doğru çözülse bile listeden düşmez.
  Future<void> updateAnswerOutcomes({
    List<String> wrongQuestionIds = const [],
    List<String> correctQuestionIds = const [],
  }) async {
    final futures = <Future<void>>[];
    if (wrongQuestionIds.isNotEmpty) {
      _wrongQuestionIds.addAll(wrongQuestionIds);
      futures.add(_persistWrongQuestions());
    }
    if (correctQuestionIds.isNotEmpty || wrongQuestionIds.isNotEmpty) {
      _solvedQuestionIds
        ..addAll(correctQuestionIds)
        ..addAll(wrongQuestionIds);
      futures.add(_persistSolvedQuestions());
    }
    if (futures.isEmpty) return;
    await Future.wait(futures);
    notifyListeners();
  }

  /// Konudaki yayınlanmış testlerdeki toplam / çözülen / çözülmeyen soru.
  ({int total, int solved, int unsolved}) topicQuestionProgress(
    KpssType type,
    String topicId,
  ) {
    final ids = <String>{};
    for (final t in testsForTopic(type, topicId)) {
      ids.addAll(t.questionIds);
    }
    final total = ids.length;
    final solved = ids.where(_solvedQuestionIds.contains).length;
    return (total: total, solved: solved, unsolved: total - solved);
  }

  bool isQuestionSolved(String questionId) =>
      _solvedQuestionIds.contains(questionId);

  TopicStatsSummary topicStats(String topicId) {
    final list = _attempts.where((a) => a.topicId == topicId).toList();
    if (list.isEmpty) {
      return TopicStatsSummary(
        topicId: topicId,
        attemptCount: 0,
        totalCorrect: 0,
        totalWrong: 0,
        totalBlank: 0,
        averageAccuracy: 0,
        averageNet: 0,
      );
    }
    final correct = list.fold(0, (s, a) => s + a.correct);
    final wrong = list.fold(0, (s, a) => s + a.wrong);
    final blank = list.fold(0, (s, a) => s + a.blank);
    final acc = list.fold(0.0, (s, a) => s + a.accuracy) / list.length;
    final net = list.fold(0.0, (s, a) => s + a.net) / list.length;
    list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return TopicStatsSummary(
      topicId: topicId,
      attemptCount: list.length,
      totalCorrect: correct,
      totalWrong: wrong,
      totalBlank: blank,
      averageAccuracy: acc,
      averageNet: net,
      lastAttemptAt: list.first.completedAt,
    );
  }

  TestStatsSummary testStats(String testId) {
    final list = _attempts.where((a) => a.testId == testId).toList();
    if (list.isEmpty) {
      return TestStatsSummary(
        testId: testId,
        attemptCount: 0,
        averageAccuracy: 0,
        bestAccuracy: 0,
        averageNet: 0,
      );
    }
    final acc = list.fold(0.0, (s, a) => s + a.accuracy) / list.length;
    final best = list.map((a) => a.accuracy).reduce((a, b) => a > b ? a : b);
    final net = list.fold(0.0, (s, a) => s + a.net) / list.length;
    list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return TestStatsSummary(
      testId: testId,
      attemptCount: list.length,
      averageAccuracy: acc,
      bestAccuracy: best,
      averageNet: net,
      lastAttemptAt: list.first.completedAt,
    );
  }

  GlobalStatsSummary globalStats() {
    if (_attempts.isEmpty) {
      return const GlobalStatsSummary(
        totalAttempts: 0,
        totalQuestionsAnswered: 0,
        totalCorrect: 0,
        overallAccuracy: 0,
        overallNet: 0,
        topicsPracticed: 0,
        studyMinutes: 0,
      );
    }
    final correct = _attempts.fold(0, (s, a) => s + a.correct);
    final totalQ = _attempts.fold(0, (s, a) => s + a.total);
    final wrong = _attempts.fold(0, (s, a) => s + a.wrong);
    final minutes = _attempts.fold(
      0,
      (s, a) => s + a.duration.inMinutes,
    );
    final topics = _attempts.map((a) => a.topicId).toSet().length;
    return GlobalStatsSummary(
      totalAttempts: _attempts.length,
      totalQuestionsAnswered: totalQ,
      totalCorrect: correct,
      overallAccuracy: totalQ == 0 ? 0 : correct / totalQ,
      overallNet: correct - (wrong / 4),
      topicsPracticed: topics,
      studyMinutes: minutes,
    );
  }

  Future<void> _persistAll({bool skipQuestions = false}) async {
    await Future.wait([
      _persistConfigs(),
      _persistTests(),
      _persistAttempts(),
      _persistSolvedQuestions(),
      _persistWrongQuestions(),
      if (!skipQuestions && _fullQuestionBankPersisted) _persistQuestions(),
      _persistLessons(),
      _persistDailyAdBonuses(),
      _persistCatalogSubjects(),
    ]);
  }

  Future<void> _persistCatalogSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = KpssCurriculum.exportCatalogJson();
    if (raw != null) {
      await prefs.setString(_kCatalogSubjects, raw);
    } else {
      await prefs.remove(_kCatalogSubjects);
    }
  }

  Future<void> _persistConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final map = {for (final e in _configs.entries) e.key: e.value.toJson()};
    await prefs.setString(_kConfigs, jsonEncode(map));
  }

  Future<void> _persistTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kTests,
      jsonEncode(_tests.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _persistAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kAttempts,
      jsonEncode(_attempts.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _persistSolvedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSolvedQuestions,
      jsonEncode(_solvedQuestionIds.toList()),
    );
  }

  Future<void> _persistWrongQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kWrongQuestions,
      jsonEncode(_wrongQuestionIds.toList()),
    );
  }

  Future<void> _persistQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kQuestions,
      jsonEncode(_questions.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _persistLessons() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kLessons,
      jsonEncode(_lessons.map((e) => e.toJson()).toList()),
    );
  }

  void _seedSampleQuestions() {
    final now = DateTime.now();
    _questions.addAll([
      QuestionModel(
        id: 'q_tr_1',
        dersAdi: 'Türkçe',
        konuAdi: 'Anlam Bilgisi',
        altKonuAdi: 'Sözcükte Anlam',
        soruMetni:
            '"Kalemi güçlü bir yazardır." cümlesinde altı çizili sözün anlamı aşağıdakilerden hangisidir?',
        siklar: const {
          'A': 'Yazı yazma aracı sağlamdır',
          'B': 'Anlatımı etkilidir',
          'C': 'Fiziksel gücü fazladır',
          'D': 'Çok kitap okur',
          'E': 'Hızlı yazar',
        },
        dogruCevap: 'B',
        cozumMetni:
            '"Kalemi güçlü" mecazı, yazarın anlatımının etkili olduğunu belirtir.',
        guncellenmeTarihi: now,
      ),
      QuestionModel(
        id: 'q_tr_2',
        dersAdi: 'Türkçe',
        konuAdi: 'Anlam Bilgisi',
        altKonuAdi: 'Cümlede Anlam',
        soruMetni:
            'Aşağıdaki cümlelerin hangisinde "karşıtlık" ilişkisi vardır?',
        siklar: const {
          'A': 'Hava güneşliydi ve herkes dışarıdaydı.',
          'B': 'Çalıştı; ancak istediği sonucu alamadı.',
          'C': 'Kitabı bitirdi, sonra uyudu.',
          'D': 'Yağmur yağdığı için evde kaldık.',
          'E': 'Hem çay hem kahve içti.',
        },
        dogruCevap: 'B',
        cozumMetni: '"Ancak" bağlacı karşıtlık bildirir.',
        guncellenmeTarihi: now,
      ),
      QuestionModel(
        id: 'q_mat_1',
        dersAdi: 'Matematik',
        konuAdi: 'Temel Kavramlar',
        altKonuAdi: 'Sayılar',
        soruMetni: '3² + 4² işleminin sonucu kaçtır?',
        siklar: const {
          'A': '7',
          'B': '12',
          'C': '25',
          'D': '49',
          'E': '5',
        },
        dogruCevap: 'C',
        cozumMetni: '9 + 16 = 25',
        guncellenmeTarihi: now,
      ),
    ]);
  }

  void _seedSampleTests() {
    _tests.add(
      TopicTestModel(
        id: 'test_seed_tr_anlam',
        topicId: 'turkce_anlam',
        kpssType: KpssType.lisans,
        title: 'Anlam Bilgisi · Tanışma Testi',
        description: 'Konuya ısınma — 2 soruluk örnek paket',
        questionCount: 2,
        questionIds: const ['q_tr_1', 'q_tr_2'],
        createdAt: DateTime.now(),
      ),
    );
  }

  void _seedSampleLessons() {
    _lessons.add(
      const TopicLessonModel(
        id: 'les_tr_anlam_1',
        topicId: 'turkce_anlam',
        title: 'Sözcükte Anlam — Temel',
        body: 'Gerçek anlam, kelimenin ilk akla gelen temel anlamıdır. '
            'Mecaz anlam ise kelimenin gerçek anlamından uzaklaşarak '
            'kazandığı yeni anlamdır.\n\n'
            'Yan anlam, gerçek anlamdan türeyen yakınlık bağı olan anlamlardır.',
        sortOrder: 0,
      ),
    );
  }
}
