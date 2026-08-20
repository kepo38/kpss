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
import 'auth_service.dart';
import 'favorites_service.dart';

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
  /// Yanlış defteri soru gövdeleri — katalog/oturum temizlenince kaybolmasın.
  static const _kWrongQuestionBodies = 'content_wrong_question_bodies';
  /// Yanlış defterinde gösterilecek işaretlenmiş şık (soruId → A–E).
  static const _kWrongQuestionSelections = 'content_wrong_question_selections';
  /// Bitmiş testte yanlış kalan sorular — sonradan doğru cevap istatistiğe yazılmaz.
  static const _kStatLockedWrongQuestions = 'content_stat_locked_wrong_questions';
  static const _kQuestions = 'content_questions';
  static const _kLessons = 'content_lessons';
  static const _kSummaryCards = 'content_summary_cards';
  static const _kPackVersion = 'content_pack_version';
  static const _kDailyAdBonuses = 'content_daily_ad_test_bonuses';
  static const _kCatalogSubjects = 'content_catalog_subjects';

  /// Yerel demo seed — production/misafir yanlış defterine sızmamalı.
  static const _sampleSeedQuestionIds = {
    'q_tr_1',
    'q_tr_2',
    'q_mat_1',
  };
  static const _sampleSeedTestId = 'test_seed_tr_anlam';

  /// Ders başına günde en fazla kaç kez reklamla ek test hakkı kazanılır.
  static const dailyAdBonusPerSubject = 1;

  static const dailyFreeTestsPerSubject = 1;

  final Map<String, TopicTestConfig> _configs = {};
  final List<TopicTestModel> _tests = [];
  final List<TestAttemptModel> _attempts = [];
  final List<QuestionModel> _questions = [];
  final List<TopicLessonModel> _lessons = [];
  final List<TopicSummaryCardModel> _summaryCards = [];
  final Set<String> _solvedQuestionIds = {};
  final Set<String> _wrongQuestionIds = {};
  final Map<String, String> _wrongQuestionSelections = {};
  final Set<String> _statLockedWrongQuestions = {};
  final Set<String> _cachedWrongBodyIds = {};
  String? _activeUserScopeId;
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

  String get _userScopeId => AuthService.instance.user?.id ?? 'unknown';

  String _scopedKey(String base) => '${base}_$_userScopeId';

  String _scopedKeyFor(String base, String userId) => '${base}_$userId';

  /// Google / misafir oturumu değişince yanlış defteri verisini yeniden yükle.
  Future<void> onUserSessionChanged() async {
    if (!_loaded) {
      await initialize();
      return;
    }
    final previous = _activeUserScopeId;
    final scope = _userScopeId;
    if (previous == scope) return;
    _dropCachedWrongBodies();
    final prefs = await SharedPreferences.getInstance();
    if (_shouldMigrateGuestWrongNotebook(previous, scope)) {
      await _migrateWrongNotebookScope(
        prefs,
        fromUserId: previous!,
        toUserId: scope,
      );
    }
    await _migrateLegacyWrongNotebookKeys(prefs);
    _loadUserWrongNotebookFromPrefs(prefs);
    notifyListeners();
  }

  bool _shouldMigrateGuestWrongNotebook(String? fromUserId, String toUserId) {
    if (fromUserId == null || fromUserId.isEmpty || fromUserId == toUserId) {
      return false;
    }
    // Yalnızca kalıcı (Google) hesaba geçerken misafir/anonim defteri taşı.
    if (!AuthService.instance.hasPermanentAccount) return false;
    return true;
  }

  Future<void> _migrateWrongNotebookScope(
    SharedPreferences prefs, {
    required String fromUserId,
    required String toUserId,
  }) async {
    await _mergeStringListPref(
      prefs,
      fromKey: _scopedKeyFor(_kWrongQuestions, fromUserId),
      toKey: _scopedKeyFor(_kWrongQuestions, toUserId),
    );
    await _mergeStringListPref(
      prefs,
      fromKey: _scopedKeyFor(_kStatLockedWrongQuestions, fromUserId),
      toKey: _scopedKeyFor(_kStatLockedWrongQuestions, toUserId),
    );
    await _mergeStringMapPref(
      prefs,
      fromKey: _scopedKeyFor(_kWrongQuestionSelections, fromUserId),
      toKey: _scopedKeyFor(_kWrongQuestionSelections, toUserId),
    );
    await _mergeStringMapPref(
      prefs,
      fromKey: _scopedKeyFor(_kWrongQuestionBodies, fromUserId),
      toKey: _scopedKeyFor(_kWrongQuestionBodies, toUserId),
    );
  }

  Future<void> _mergeStringListPref(
    SharedPreferences prefs, {
    required String fromKey,
    required String toKey,
  }) async {
    final fromRaw = prefs.getString(fromKey);
    if (fromRaw == null || fromRaw.isEmpty) return;
    final merged = <String>{};
    try {
      final fromList = jsonDecode(fromRaw);
      if (fromList is List) {
        merged.addAll(fromList.map((e) => e.toString()));
      }
    } catch (_) {
      return;
    }
    final toRaw = prefs.getString(toKey);
    if (toRaw != null && toRaw.isNotEmpty) {
      try {
        final toList = jsonDecode(toRaw);
        if (toList is List) {
          merged.addAll(toList.map((e) => e.toString()));
        }
      } catch (_) {}
    }
    await prefs.setString(toKey, jsonEncode(merged.toList()));
    await prefs.remove(fromKey);
  }

  Future<void> _mergeStringMapPref(
    SharedPreferences prefs, {
    required String fromKey,
    required String toKey,
  }) async {
    final fromRaw = prefs.getString(fromKey);
    if (fromRaw == null || fromRaw.isEmpty) return;
    final merged = <String, dynamic>{};
    try {
      final fromMap = jsonDecode(fromRaw);
      if (fromMap is Map) {
        fromMap.forEach((k, v) {
          merged[k.toString()] = v;
        });
      }
    } catch (_) {
      return;
    }
    final toRaw = prefs.getString(toKey);
    if (toRaw != null && toRaw.isNotEmpty) {
      try {
        final toMap = jsonDecode(toRaw);
        if (toMap is Map) {
          toMap.forEach((k, v) {
            merged.putIfAbsent(k.toString(), () => v);
          });
        }
      } catch (_) {}
    }
    await prefs.setString(toKey, jsonEncode(merged));
    await prefs.remove(fromKey);
  }

  void _dropCachedWrongBodies() {
    if (_cachedWrongBodyIds.isEmpty) return;
    _questions.removeWhere((q) => _cachedWrongBodyIds.contains(q.id));
    _cachedWrongBodyIds.clear();
  }

  Future<void> _migrateLegacyWrongNotebookKeys(SharedPreferences prefs) async {
    final pairs = [
      (_kWrongQuestions, _scopedKey(_kWrongQuestions)),
      (_kWrongQuestionBodies, _scopedKey(_kWrongQuestionBodies)),
      (_kWrongQuestionSelections, _scopedKey(_kWrongQuestionSelections)),
      (_kStatLockedWrongQuestions, _scopedKey(_kStatLockedWrongQuestions)),
    ];
    for (final pair in pairs) {
      final legacy = pair.$1;
      final scoped = pair.$2;
      if (prefs.containsKey(scoped) || !prefs.containsKey(legacy)) continue;
      final value = prefs.getString(legacy);
      if (value != null && value.isNotEmpty) {
        await prefs.setString(scoped, value);
      }
      await prefs.remove(legacy);
    }
  }

  void _loadUserWrongNotebookFromPrefs(SharedPreferences prefs) {
    _wrongQuestionIds.clear();
    _wrongQuestionSelections.clear();
    _statLockedWrongQuestions.clear();

    final wrongRaw = prefs.getString(_scopedKey(_kWrongQuestions));
    if (wrongRaw != null) {
      final list = jsonDecode(wrongRaw) as List<dynamic>;
      _wrongQuestionIds.addAll(list.map((e) => e.toString()));
    }

    final wrongSelRaw = prefs.getString(_scopedKey(_kWrongQuestionSelections));
    if (wrongSelRaw != null) {
      final map = jsonDecode(wrongSelRaw) as Map<String, dynamic>;
      _wrongQuestionSelections.addAll(
        map.map((k, v) => MapEntry(k, v.toString())),
      );
    }

    final statLockedRaw =
        prefs.getString(_scopedKey(_kStatLockedWrongQuestions));
    if (statLockedRaw != null) {
      final list = jsonDecode(statLockedRaw) as List<dynamic>;
      _statLockedWrongQuestions.addAll(list.map((e) => e.toString()));
    }

    _pruneSampleSeedProgress();
    _mergeWrongQuestionBodies(
      prefs.getString(_scopedKey(_kWrongQuestionBodies)),
    );
    _activeUserScopeId = _userScopeId;
  }

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

    final summaryRaw = prefs.getString(_kSummaryCards);
    if (summaryRaw != null) {
      final list = jsonDecode(summaryRaw) as List<dynamic>;
      _summaryCards
        ..clear()
        ..addAll(
          list.map(
            (e) => TopicSummaryCardModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
    }

    if (_questions.isEmpty && kDebugMode) {
      _seedSampleQuestions();
      _fullQuestionBankPersisted = false;
    } else if (_questions.isEmpty) {
      _fullQuestionBankPersisted = false;
    } else {
      _fullQuestionBankPersisted = true;
    }
    if (_tests.isEmpty && kDebugMode) {
      _seedSampleTests();
    }
    if (_lessons.isEmpty && kDebugMode) {
      _seedSampleLessons();
    }

    // Eski demo seed kalıntılarını yanlış/çözülen listelerinden temizle.
    final prunedSeed = _pruneSampleSeedProgress();
    if (!kDebugMode) {
      _tests.removeWhere(
        (t) => t.id == _sampleSeedTestId || t.id.startsWith('test_seed_'),
      );
      _questions.removeWhere((q) => _sampleSeedQuestionIds.contains(q.id));
    }

    await _migrateLegacyWrongNotebookKeys(prefs);
    _loadUserWrongNotebookFromPrefs(prefs);
    final restoredBodies = _cachedWrongBodyIds.isNotEmpty;

    KpssCurriculum.loadCatalogFromJsonString(
      prefs.getString(_kCatalogSubjects),
    );

    _loaded = true;
    if (prunedSeed ||
        restoredBodies ||
        (_questions.isEmpty && kDebugMode)) {
      unawaited(_persistAll(skipQuestions: !_fullQuestionBankPersisted));
    }
  }

  /// Django hafif kataloğunu uygular — soru gövdeleri indirilmez.
  Future<void> applyCatalogPack(Map<String, dynamic> pack) async {
    await initialize();
    await _applyPackMetadata(pack);
    // Yanlış defteri gövdelerini katalog temizlemesinde kaybetme.
    final keepWrong = _questions
        .where((q) => _wrongQuestionIds.contains(q.id))
        .toList();
    _questions
      ..clear()
      ..addAll(keepWrong);
    _fullQuestionBankPersisted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQuestions);
    await Future.wait([
      _persistAll(skipQuestions: true),
      _persistWrongQuestionBodies(),
    ]);
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

  /// Oturum içi sorular — yanlış defterindekiler ayrıca diske yazılır.
  void mergeSessionQuestions(Iterable<QuestionModel> questions) {
    var touchedWrong = false;
    for (final q in questions) {
      final idx = _questions.indexWhere((item) => item.id == q.id);
      if (idx >= 0) {
        _questions[idx] = q;
      } else {
        _questions.add(q);
        if (_wrongQuestionIds.contains(q.id)) {
          _cachedWrongBodyIds.add(q.id);
        }
      }
      if (_wrongQuestionIds.contains(q.id)) touchedWrong = true;
    }
    if (touchedWrong) {
      unawaited(_persistWrongQuestionBodies());
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
    final parserSummary = (pack['summaryCards'] as List<dynamic>? ?? const [])
        .map(
          (e) => TopicSummaryCardModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
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
    _summaryCards
      ..clear()
      ..addAll(parserSummary);

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
    return QuestionModel.interleaveOsymSordu(
      QuestionModel.keepGroupsContiguous(
        test.questionIds
            .map((id) => byId[id])
            .whereType<QuestionModel>()
            .toList(),
      ),
    );
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
      subjectQuestionProgress(type, subjectId).total;

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

  List<TopicSummaryCardModel> summaryCardsForTopic(String topicId) {
    return _summaryCards.where((c) => c.topicId == topicId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  TopicSummaryCardModel? summaryCardById(String id) {
    for (final c in _summaryCards) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<TopicSummaryCardModel> summaryCardsByIds(Iterable<String> ids) {
    final map = {for (final c in _summaryCards) c.id: c};
    return [
      for (final id in ids)
        if (map[id] != null) map[id]!,
    ];
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
    List<String?> selectedAnswers = const [],
  }) async {
    _attempts.add(attempt);
    final futures = <Future<void>>[_persistAttempts()];
    if (questionIds.isNotEmpty) {
      _solvedQuestionIds.addAll(questionIds);
      futures.add(_persistSolvedQuestions());
    }
    if (wrongQuestionIds.isNotEmpty) {
      _wrongQuestionIds.addAll(wrongQuestionIds);
      _mergeWrongSelections(questionIds, wrongQuestionIds, selectedAnswers);
      _statLockedWrongQuestions.addAll(wrongQuestionIds);
      futures.add(_persistWrongQuestions());
      futures.add(_persistWrongQuestionBodies());
      futures.add(_persistWrongSelections());
      futures.add(_persistStatLockedWrongQuestions());
    }
    await Future.wait(futures);
    notifyListeners();
    unawaited(UserSavingsInsightService.instance.handleTestCompleted());
  }

  /// Tasarruf hesabı ve istatistikler için salt okunur deneme listesi.
  List<TestAttemptModel> get allAttempts => List.unmodifiable(_attempts);

  /// Tamamlanan konu testi sayısı (günün mini denemesi hariç).
  int get completedTopicTestCount =>
      _attempts.where(countsTowardDailyHomework).length;

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
      final inSubject = topicIds.contains(a.topicId);
      final mapSpecial = subjectId == 'cografya' &&
          a.testId.startsWith('special_map_cografya');
      if (!inSubject && !mapSpecial) return false;
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

  Set<String> get wrongQuestionIds => Set.unmodifiable(_visibleWrongQuestionIds);

  int get wrongQuestionCount => _visibleWrongQuestionIds.length;

  /// Normal testte «defterde kayıtlı» uyarısı — gövde cache’inden bağımsız ID kontrolü.
  bool isInWrongNotebook(String questionId) {
    if (_sampleSeedQuestionIds.contains(questionId)) return false;
    return _wrongQuestionIds.contains(questionId);
  }

  bool get hasCompletedAnyTest =>
      _attempts.any(countsTowardDailyHomework);

  /// Liste ve sayaç yalnızca yerelde gövdesi olan yanlışları gösterir.
  Set<String> get _visibleWrongQuestionIds {
    final local = {for (final q in _questions) q.id};
    return _wrongQuestionIds.where((id) {
      if (_sampleSeedQuestionIds.contains(id)) return false;
      return local.contains(id);
    }).toSet();
  }

  /// Gövdesi henüz yüklenmemiş yanlış ID'ler (API ile doldurulabilir).
  List<String> get unresolvedWrongQuestionIds {
    final local = {for (final q in _questions) q.id};
    return _wrongQuestionIds
        .where(
          (id) =>
              !_sampleSeedQuestionIds.contains(id) && !local.contains(id),
        )
        .toList()
      ..sort();
  }

  bool _pruneSampleSeedProgress() {
    final beforeWrong = _wrongQuestionIds.length;
    final beforeSolved = _solvedQuestionIds.length;
    _wrongQuestionIds.removeAll(_sampleSeedQuestionIds);
    _solvedQuestionIds.removeAll(_sampleSeedQuestionIds);
    return beforeWrong != _wrongQuestionIds.length ||
        beforeSolved != _solvedQuestionIds.length;
  }

  bool _mergeWrongQuestionBodies(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final bodies = list
          .map(
            (e) =>
                QuestionModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .where((q) => _wrongQuestionIds.contains(q.id))
          .where((q) => !_sampleSeedQuestionIds.contains(q.id))
          .toList();
      if (bodies.isEmpty) return false;
      mergeSessionQuestions(bodies);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// En çok yanlış yapılan konular (ders · konu, adet).
  List<(String topicLabel, int count)> wrongTopicsSummary({int limit = 3}) {
    final counts = <String, int>{};
    for (final id in _visibleWrongQuestionIds) {
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
    _wrongQuestionSelections.remove(questionId);
    await Future.wait([
      _persistWrongQuestions(),
      _persistWrongQuestionBodies(),
      _persistWrongSelections(),
      FavoritesService.instance.remove(questionId),
    ]);
    notifyListeners();
  }

  String? wrongSelectionFor(String questionId) =>
      _wrongQuestionSelections[questionId];

  bool isStatLockedForQuestion(String questionId) =>
      _statLockedWrongQuestions.contains(questionId);

  Set<String> get statLockedWrongQuestionIds =>
      Set.unmodifiable(_statLockedWrongQuestions);

  void _mergeWrongSelections(
    List<String> questionIds,
    List<String> wrongQuestionIds,
    List<String?> selectedAnswers,
  ) {
    if (questionIds.isEmpty ||
        selectedAnswers.isEmpty ||
        questionIds.length != selectedAnswers.length) {
      return;
    }
    for (var i = 0; i < questionIds.length; i++) {
      final id = questionIds[i];
      if (!wrongQuestionIds.contains(id)) continue;
      final selected = selectedAnswers[i]?.trim().toUpperCase() ?? '';
      if (RegExp(r'^[A-E]$').hasMatch(selected)) {
        _wrongQuestionSelections[id] = selected;
      }
    }
  }

  /// Yanlış listesine ekle; doğru çözülse bile listeden düşmez.
  Future<void> updateAnswerOutcomes({
    List<String> wrongQuestionIds = const [],
    List<String> correctQuestionIds = const [],
    List<String> questionIds = const [],
    List<String?> selectedAnswers = const [],
  }) async {
    final futures = <Future<void>>[];
    if (wrongQuestionIds.isNotEmpty) {
      _wrongQuestionIds.addAll(wrongQuestionIds);
      _mergeWrongSelections(questionIds, wrongQuestionIds, selectedAnswers);
      futures.add(_persistWrongQuestions());
      futures.add(_persistWrongQuestionBodies());
      futures.add(_persistWrongSelections());
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

  /// Dersteki yayınlanmış testlerdeki toplam / çözülen / çözülmeyen soru.
  ({int total, int solved, int unsolved}) subjectQuestionProgress(
    KpssType type,
    String subjectId,
  ) {
    final ids = catalogQuestionIdsForSubject(type, subjectId);
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
      _persistWrongQuestionBodies(),
      if (!skipQuestions && _fullQuestionBankPersisted) _persistQuestions(),
      _persistLessons(),
      _persistSummaryCards(),
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
    final key = _scopedKey(_kWrongQuestions);
    if (_wrongQuestionIds.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(_wrongQuestionIds.toList()));
  }

  Future<void> _persistWrongSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_kWrongQuestionSelections);
    if (_wrongQuestionSelections.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(_wrongQuestionSelections));
  }

  Future<void> _persistStatLockedWrongQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_kStatLockedWrongQuestions);
    if (_statLockedWrongQuestions.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(_statLockedWrongQuestions.toList()));
  }

  Future<void> _persistWrongQuestionBodies() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_kWrongQuestionBodies);
    final bodies = _questions
        .where((q) => _wrongQuestionIds.contains(q.id))
        .where((q) => !_sampleSeedQuestionIds.contains(q.id))
        .map((q) => q.toJson())
        .toList();
    if (bodies.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(bodies));
    }
  }

  /// API'den doldurulan yanlış gövdelerini diske yaz (yanlış defteri ekranı).
  Future<void> persistWrongQuestionBodiesNow() async {
    await initialize();
    await _persistWrongQuestionBodies();
    notifyListeners();
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

  Future<void> _persistSummaryCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSummaryCards,
      jsonEncode(_summaryCards.map((e) => e.toJson()).toList()),
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
