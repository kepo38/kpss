import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/daily_mini_exam_constants.dart';
import '../constants/savings_constants.dart';
import '../data/kpss_curriculum.dart';
import '../models/content_models.dart';
import '../models/manual_question_model.dart';
import '../models/question_model.dart';
import '../utils/daily_mission_copy.dart';
import '../widgets/countdown_widget.dart';
import 'user_savings_insight_service.dart';
import 'auth_service.dart';
import 'content_bank_isolate.dart';
import 'daily_quota_service.dart';
import 'favorites_service.dart';
import 'local_database.dart';
import 'premium_service.dart';

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
  /// Yanlış defteri soru durumu (soruId → fresh/repeat/solved).
  static const _kWrongQuestionStatuses = 'content_wrong_question_statuses';
  /// Bitmiş testte yanlış kalan sorular — sonradan doğru cevap istatistiğe yazılmaz.
  static const _kStatLockedWrongQuestions = 'content_stat_locked_wrong_questions';
  static const _kQuestions = 'content_questions';
  static const _kLessons = 'content_lessons';
  static const _kSummaryCards = 'content_summary_cards';
  static const _kPackVersion = 'content_pack_version';
  static const _kDailyAdBonuses = 'content_daily_ad_test_bonuses';
  static const _kCatalogSubjects = 'content_catalog_subjects';
  /// Cihaz geneli: misafir→Google / çoklu hesap ile ücretsiz hakkın çift kullanımı.
  static const _kDeviceDailyFree = 'content_device_daily_free_consumed';

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
  final Map<String, ManualQuestionStatus> _wrongQuestionStatuses = {};
  final Set<String> _statLockedWrongQuestions = {};
  final Set<String> _cachedWrongBodyIds = {};
  String? _activeUserScopeId;
  final Map<String, int> _dailyAdBonuses = {};
  /// subjectId_yyyy-MM-dd → bu cihazda bugün yakılan ücretsiz hak (0/1).
  final Map<String, int> _deviceDailyFreeConsumed = {};
  int? _packVersion;
  bool _loaded = false;
  bool _fullQuestionBankPersisted = false;
  Future<void>? _initFuture;

  /// Katalog / pack değişince artar — StudyHub yapısal dinleyici.
  final ValueNotifier<int> catalogRevision = ValueNotifier(0);

  /// Çözüm / yanlış / kota değişince artar — ilerleme satırları.
  final ValueNotifier<int> progressRevision = ValueNotifier(0);

  Timer? _catalogNotifyTimer;
  Timer? _progressNotifyTimer;
  static const _notifyDebounce = Duration(milliseconds: 80);

  int? get packVersion => _packVersion;

  void _bumpCatalog() {
    catalogRevision.value++;
  }

  void _bumpProgress() {
    progressRevision.value++;
  }

  void _notifyCatalog({bool urgent = false}) {
    if (urgent) {
      _catalogNotifyTimer?.cancel();
      _catalogNotifyTimer = null;
      _bumpCatalog();
      notifyListeners();
      return;
    }
    _catalogNotifyTimer?.cancel();
    _catalogNotifyTimer = Timer(_notifyDebounce, () {
      _catalogNotifyTimer = null;
      _bumpCatalog();
      notifyListeners();
    });
  }

  void _notifyProgress({bool urgent = false}) {
    if (urgent) {
      _progressNotifyTimer?.cancel();
      _progressNotifyTimer = null;
      _bumpProgress();
      notifyListeners();
      return;
    }
    _progressNotifyTimer?.cancel();
    _progressNotifyTimer = Timer(_notifyDebounce, () {
      _progressNotifyTimer = null;
      _bumpProgress();
      notifyListeners();
    });
  }

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

  /// Google / misafir oturumu değişince kullanıcıya özel ilerleme + yanlış defteri.
  /// [previousUserId] — giriş öncesi misafir kimliği (AuthService aktarır).
  Future<void> onUserSessionChanged({String? previousUserId}) async {
    var previous = previousUserId ?? _activeUserScopeId;
    if (!_loaded) {
      await initialize();
    }
    final scope = _userScopeId;
    previous ??= await _inferGuestScopeForMigration(scope);
    if (previous == null || previous.isEmpty || previous == scope) return;
    _dropCachedWrongBodies();
    final prefs = await SharedPreferences.getInstance();
    if (_shouldMigrateGuestWrongNotebook(previous, scope)) {
      await _migrateWrongNotebookScope(
        prefs,
        fromUserId: previous,
        toUserId: scope,
      );
    }
    // Günlük test kotası / denemeler hesaplar arası taşınmaz (misafir→Google dahil).
    await _migrateLegacyWrongNotebookKeys(prefs);
    await _migrateLegacyQuotaProgressKeys(prefs);
    _loadDeviceDailyFree(prefs.getString(_kDeviceDailyFree));
    _loadUserWrongNotebookFromPrefs(prefs);
    _loadUserQuotaProgressFromPrefs(prefs);
    await _syncDeviceFreeFromUserAttempts();
    _pruneSampleSeedProgress();
    _notifyProgress(urgent: true);
  }

  /// Yerel misafir (`guest-…`) defteri — oturum değişiminde yedek eşleme.
  Future<String?> _inferGuestScopeForMigration(String toUserId) async {
    if (!AuthService.instance.hasPermanentAccount) return null;
    final prefs = await SharedPreferences.getInstance();
    const localGuestKey = 'local_guest_id';
    final localGuest = prefs.getString(localGuestKey);
    if (localGuest != null &&
        localGuest.isNotEmpty &&
        localGuest != toUserId &&
        prefs.containsKey(_scopedKeyFor(_kWrongQuestions, localGuest))) {
      return localGuest;
    }
    return null;
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
    await _mergeStringMapPref(
      prefs,
      fromKey: _scopedKeyFor(_kWrongQuestionStatuses, fromUserId),
      toKey: _scopedKeyFor(_kWrongQuestionStatuses, toUserId),
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
      (_kWrongQuestionStatuses, _scopedKey(_kWrongQuestionStatuses)),
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

  /// Eski cihaz geneli deneme/kota anahtarlarını yalnızca misafire taşı.
  /// Google hesapları misafir kotasını miras almasın.
  Future<void> _migrateLegacyQuotaProgressKeys(SharedPreferences prefs) async {
    const bases = [_kAttempts, _kSolvedQuestions, _kDailyAdBonuses];
    final permanent = AuthService.instance.hasPermanentAccount;
    for (final base in bases) {
      final legacy = prefs.getString(base);
      if (legacy == null || legacy.isEmpty) continue;
      final scoped = _scopedKey(base);
      final existing = prefs.getString(scoped);
      if (existing != null && existing.isNotEmpty) {
        await prefs.remove(base);
        continue;
      }
      if (permanent) {
        // Misafirken kullanılan günlük hak Google / diğer Google'lara yapışmasın.
        await prefs.remove(base);
        continue;
      }
      await prefs.setString(scoped, legacy);
      await prefs.remove(base);
    }
  }

  void _loadUserQuotaProgressFromPrefs(SharedPreferences prefs) {
    _attempts.clear();
    _solvedQuestionIds.clear();
    _dailyAdBonuses.clear();

    final attemptsRaw = prefs.getString(_scopedKey(_kAttempts));
    if (attemptsRaw != null && attemptsRaw.isNotEmpty) {
      try {
        final list = jsonDecode(attemptsRaw) as List<dynamic>;
        for (final e in list) {
          if (e is! Map) continue;
          _attempts.add(
            TestAttemptModel.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      } catch (e) {
        debugPrint('Attempts load: $e');
      }
    }

    final solvedRaw = prefs.getString(_scopedKey(_kSolvedQuestions));
    if (solvedRaw != null && solvedRaw.isNotEmpty) {
      try {
        final list = jsonDecode(solvedRaw) as List<dynamic>;
        _solvedQuestionIds.addAll(list.map((e) => e.toString()));
      } catch (e) {
        debugPrint('Solved load: $e');
      }
    }

    _loadDailyAdBonuses(prefs.getString(_scopedKey(_kDailyAdBonuses)));
    _activeUserScopeId = _userScopeId;
  }

  void _loadUserWrongNotebookFromPrefs(SharedPreferences prefs) {
    _wrongQuestionIds.clear();
    _wrongQuestionSelections.clear();
    _wrongQuestionStatuses.clear();
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

    final wrongStatusRaw =
        prefs.getString(_scopedKey(_kWrongQuestionStatuses));
    if (wrongStatusRaw != null) {
      final map = jsonDecode(wrongStatusRaw) as Map<String, dynamic>;
      map.forEach((key, value) {
        try {
          _wrongQuestionStatuses[key.toString()] =
              ManualQuestionStatus.values.byName(value.toString());
        } catch (_) {}
      });
    }

    final statLockedRaw =
        prefs.getString(_scopedKey(_kStatLockedWrongQuestions));
    if (statLockedRaw != null) {
      final list = jsonDecode(statLockedRaw) as List<dynamic>;
      _statLockedWrongQuestions.addAll(list.map((e) => e.toString()));
    }

    _pruneSampleSeedProgress();
    _pruneWrongQuestionStatuses();
    _mergeWrongQuestionBodies(
      prefs.getString(_scopedKey(_kWrongQuestionBodies)),
    );
    _activeUserScopeId = _userScopeId;
  }

  Future<void> initialize() {
    if (_loaded) return Future<void>.value();
    return _initFuture ??= _initializeBody();
  }

  Future<void> _initializeBody() async {
    final prefs = await SharedPreferences.getInstance();
    _packVersion = prefs.getInt(_kPackVersion);

    // Sorular: SQLite (tercih) → legacy SharedPreferences.
    String? questionsRaw;
    try {
      await LocalDatabase.instance.initialize();
      questionsRaw = await LocalDatabase.instance.loadContentQuestionsJson();
    } catch (e, st) {
      debugPrint('ContentBank SQLite question load: $e\n$st');
    }
    final legacyQuestions = prefs.getString(_kQuestions);
    if (questionsRaw == null || questionsRaw.isEmpty) {
      questionsRaw = legacyQuestions;
    } else if (legacyQuestions != null && legacyQuestions.isNotEmpty) {
      // SQLite'a taşındı — prefs şişmesini kes.
      unawaited(prefs.remove(_kQuestions));
    }

    // Prefs string'leri main'de oku; decode+fromJson arka isolate'ta.
    // Deneme / çözülen / günlük bonus kullanıcıya özel — burada yüklenmez.
    final raw = ContentBankRawBundle(
      configs: prefs.getString(_kConfigs),
      tests: prefs.getString(_kTests),
      attempts: null,
      solved: null,
      questions: questionsRaw,
      lessons: prefs.getString(_kLessons),
      summaryCards: prefs.getString(_kSummaryCards),
    );
    // compute: top-level fn + sendable payload (no async-closure / this capture).
    final parsed = await compute(parseContentBankBundle, raw);

    _configs
      ..clear()
      ..addAll(parsed.configs);
    _tests
      ..clear()
      ..addAll(parsed.tests);
    _attempts.clear();
    _solvedQuestionIds.clear();
    _questions
      ..clear()
      ..addAll(parsed.questions);
    _lessons
      ..clear()
      ..addAll(parsed.lessons);
    _summaryCards
      ..clear()
      ..addAll(parsed.summaryCards);
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
    if (!kDebugMode) {
      _tests.removeWhere(
        (t) => t.id == _sampleSeedTestId || t.id.startsWith('test_seed_'),
      );
      _questions.removeWhere((q) => _sampleSeedQuestionIds.contains(q.id));
    }

    await _migrateLegacyWrongNotebookKeys(prefs);
    await _migrateLegacyQuotaProgressKeys(prefs);
    _loadDeviceDailyFree(prefs.getString(_kDeviceDailyFree));
    _loadUserWrongNotebookFromPrefs(prefs);
    _loadUserQuotaProgressFromPrefs(prefs);
    unawaited(_syncDeviceFreeFromUserAttempts());
    final prunedSeed = _pruneSampleSeedProgress();
    final restoredBodies = _cachedWrongBodyIds.isNotEmpty;

    KpssCurriculum.loadCatalogFromJsonString(
      prefs.getString(_kCatalogSubjects),
    );

    _loaded = true;
    _notifyCatalog(urgent: true);
    if (prunedSeed ||
        restoredBodies ||
        (_questions.isEmpty && kDebugMode)) {
      unawaited(_persistAll(skipQuestions: !_fullQuestionBankPersisted));
    } else if (_fullQuestionBankPersisted &&
        legacyQuestions != null &&
        legacyQuestions.isNotEmpty) {
      // Prefs → SQLite migrasyonu (arka plan).
      unawaited(_persistQuestions());
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
    try {
      await LocalDatabase.instance.clearContentQuestionsJson();
    } catch (e, st) {
      debugPrint('ContentBank clear questions: $e\n$st');
    }
    await Future.wait([
      _persistAll(skipQuestions: true),
      _persistWrongQuestionBodies(),
    ]);
    _notifyCatalog();
  }

  /// Django tam yayın paketini yerel cache'e uygular (offline premium).
  Future<void> applyPublishedPack(Map<String, dynamic> pack) async {
    await initialize();
    final rawQuestions = pack['questions'];
    final questionList = List<dynamic>.from(
      rawQuestions as List<dynamic>? ?? const <dynamic>[],
    );
    final parserQuestions = await compute(parseQuestionMaps, questionList);

    await _applyPackMetadata(pack);

    _questions
      ..clear()
      ..addAll(parserQuestions);
    _fullQuestionBankPersisted = parserQuestions.isNotEmpty;

    await _persistAll();
    _notifyCatalog();
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
    final packPayload = Map<String, dynamic>.from(pack);
    final parsed = await compute(parseContentPackMetadata, packPayload);

    final subjectsRaw = pack['subjects'] as List<dynamic>? ?? const [];
    if (subjectsRaw.isNotEmpty) {
      KpssCurriculum.applyCatalogFromJson(subjectsRaw);
    }

    _tests
      ..clear()
      ..addAll(parsed.tests);
    if (parsed.configs.isNotEmpty) {
      _configs
        ..clear()
        ..addAll(parsed.configs);
    }
    _lessons
      ..clear()
      ..addAll(parsed.lessons);
    _summaryCards
      ..clear()
      ..addAll(parsed.summaryCards);

    if (parsed.packVersion != null) {
      _packVersion = parsed.packVersion;
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
      ..sort((a, b) => _topicTestSortKey(a).compareTo(_topicTestSortKey(b)));
  }

  static int _topicTestSortKey(TopicTestModel test) {
    final match = RegExp(r'(\d+)').firstMatch(test.title);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 9999;
    }
    return 9999 - test.createdAt.millisecondsSinceEpoch.remainder(9999);
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
    if (countsTowardDailyHomework(attempt) &&
        !PremiumService.instance.isPremium) {
      final subjectId = _subjectIdForAttempt(attempt);
      if (subjectId != null) {
        // Cihaz yanığı yalnız misafir: Google A→B geçişini kilitlemez.
        // Misafir→Google çift hakkını keser.
        if (!AuthService.instance.hasPermanentAccount) {
          await _markDeviceDailyFreeConsumed(subjectId);
        } else {
          unawaited(
            DailyQuotaService.instance.consume(subjectId).then((_) {
              _notifyProgress();
            }),
          );
        }
      }
    }
    _notifyProgress();
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
      if (a.kpssType != type) return false;
      final inSubject = topicIds.contains(a.topicId);
      final mapSpecial = subjectId == 'cografya' &&
          a.testId.startsWith('special_map_cografya');
      if (!inSubject && !mapSpecial) return false;
      final d = a.completedAt.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  /// Kota: kullanıcı denemeleri + (misafir cihaz yanığı) + Google hesap yanığı.
  /// Google hesapları birbirinin cihaz kotasını paylaşmaz.
  int dailyQuotaCompletedTestsForSubject(KpssType type, String subjectId) {
    final google = AuthService.instance.hasPermanentAccount;
    return effectiveCompletedForQuota(
      userCompleted: dailyCompletedTestsForSubject(type, subjectId),
      // Misafir yakması Google'ı da keser; Google A yakması Google B'yi kesmez.
      deviceFreeConsumed: deviceDailyFreeConsumedToday(subjectId),
      accountFreeConsumed:
          google ? DailyQuotaService.instance.freeUsedToday(subjectId) : 0,
    );
  }

  /// Bu cihazda bugün bu ders için ücretsiz hak kullanıldı mı (0/1).
  int deviceDailyFreeConsumedToday(String subjectId) {
    return _deviceDailyFreeConsumed[_deviceDailyFreeKey(subjectId)] ?? 0;
  }

  @visibleForTesting
  static int effectiveCompletedForQuota({
    required int userCompleted,
    required int deviceFreeConsumed,
    int accountFreeConsumed = 0,
  }) {
    var effective = userCompleted;
    if (deviceFreeConsumed > 0 || accountFreeConsumed > 0) {
      if (effective < dailyFreeTestsPerSubject) {
        effective = dailyFreeTestsPerSubject;
      }
    }
    return effective;
  }

  String? _subjectIdForAttempt(TestAttemptModel attempt) {
    if (attempt.testId.startsWith('special_map_cografya')) {
      return 'cografya';
    }
    final direct = KpssCurriculum.subjectIdForTopic(
      attempt.kpssType,
      attempt.topicId,
    );
    if (direct != null) return direct;
    for (final t in KpssType.values) {
      final id = KpssCurriculum.subjectIdForTopic(t, attempt.topicId);
      if (id != null) return id;
    }
    return null;
  }

  static String deviceDailyFreeKeyFor(String subjectId, DateTime day) {
    final local = day.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final dayPart = local.day.toString().padLeft(2, '0');
    return '${subjectId}_${local.year}-$month-$dayPart';
  }

  String _deviceDailyFreeKey(String subjectId) {
    return deviceDailyFreeKeyFor(subjectId, DateTime.now());
  }

  Future<void> _markDeviceDailyFreeConsumed(String subjectId) async {
    final key = _deviceDailyFreeKey(subjectId);
    final current = _deviceDailyFreeConsumed[key] ?? 0;
    if (current >= dailyFreeTestsPerSubject) return;
    _deviceDailyFreeConsumed[key] = dailyFreeTestsPerSubject;
    await _persistDeviceDailyFree();
  }

  /// Oturumdaki bugünkü denemeleri cihaz ücretsiz hakkına yansıt.
  /// Yalnız misafir — Google denemeleri cihazı yakmaz (hesaplar arası geçiş serbest).
  Future<void> _syncDeviceFreeFromUserAttempts() async {
    if (PremiumService.instance.isPremium) return;
    if (AuthService.instance.hasPermanentAccount) return;
    final now = DateTime.now();
    final touched = <String>{};
    for (final a in _attempts) {
      if (!countsTowardDailyHomework(a)) continue;
      final d = a.completedAt.toLocal();
      if (d.year != now.year || d.month != now.month || d.day != now.day) {
        continue;
      }
      final subjectId = _subjectIdForAttempt(a);
      if (subjectId == null) continue;
      final key = _deviceDailyFreeKey(subjectId);
      if ((_deviceDailyFreeConsumed[key] ?? 0) >= dailyFreeTestsPerSubject) {
        continue;
      }
      _deviceDailyFreeConsumed[key] = dailyFreeTestsPerSubject;
      touched.add(subjectId);
    }
    if (touched.isNotEmpty) {
      await _persistDeviceDailyFree();
    }
  }

  void _loadDeviceDailyFree(String? raw) {
    _deviceDailyFreeConsumed.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final todaySuffix = _todayKeySuffix();
      for (final entry in map.entries) {
        if (!entry.key.endsWith(todaySuffix)) continue;
        _deviceDailyFreeConsumed[entry.key] = (entry.value as num).toInt();
      }
    } catch (e) {
      debugPrint('Device daily free load: $e');
    }
  }

  Future<void> _persistDeviceDailyFree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kDeviceDailyFree,
      jsonEncode(_deviceDailyFreeConsumed),
    );
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
  /// Cihaz geneli ücretsiz hak yanığı misafir→Google çift kullanımı engeller.
  bool canStartDailySubjectTest(KpssType type, String subjectId) {
    return hasDailyTestQuota(
      completedTests: dailyQuotaCompletedTestsForSubject(type, subjectId),
      adBonusTests: dailyAdBonusTestsForSubject(type, subjectId),
    );
  }

  /// Günlük ücretsiz hak bittiyse reklam izleyerek +1 test kazanılabilir mi?
  bool canWatchAdForDailyTestBonus(KpssType type, String subjectId) {
    return canEarnDailyAdBonus(
      completedTests: dailyQuotaCompletedTestsForSubject(type, subjectId),
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
    _notifyProgress();
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
      _scopedKey(_kDailyAdBonuses),
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
    for (final id in _sampleSeedQuestionIds) {
      _wrongQuestionStatuses.remove(id);
    }
    return beforeWrong != _wrongQuestionIds.length ||
        beforeSolved != _solvedQuestionIds.length;
  }

  void _pruneWrongQuestionStatuses() {
    _wrongQuestionStatuses.removeWhere(
      (id, _) => !_wrongQuestionIds.contains(id),
    );
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
    _wrongQuestionStatuses.remove(questionId);
    await Future.wait([
      _persistWrongQuestions(),
      _persistWrongQuestionBodies(),
      _persistWrongSelections(),
      _persistWrongQuestionStatuses(),
      FavoritesService.instance.remove(questionId),
    ]);
    _notifyProgress();
  }

  ManualQuestionStatus wrongQuestionStatusFor(String questionId) =>
      _wrongQuestionStatuses[questionId] ?? ManualQuestionStatus.fresh;

  Future<void> setWrongQuestionStatus(
    String questionId,
    ManualQuestionStatus status,
  ) async {
    if (!_wrongQuestionIds.contains(questionId)) return;
    if (status == ManualQuestionStatus.fresh) {
      _wrongQuestionStatuses.remove(questionId);
    } else {
      _wrongQuestionStatuses[questionId] = status;
    }
    await _persistWrongQuestionStatuses();
    _notifyProgress();
  }

  String? wrongSelectionFor(String questionId) =>
      _wrongQuestionSelections[questionId];

  /// Yanlış defterinde görüntülenen / güncellenen işaretli şık.
  Future<void> setWrongQuestionSelection(
    String questionId,
    String option,
  ) async {
    if (!_wrongQuestionIds.contains(questionId)) return;
    final selected = option.trim().toUpperCase();
    if (!RegExp(r'^[A-E]$').hasMatch(selected)) return;
    if (_wrongQuestionSelections[questionId] == selected) return;
    _wrongQuestionSelections[questionId] = selected;
    await _persistWrongSelections();
    _notifyProgress();
  }

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
        questionIds.length != selectedAnswers.length ||
        wrongQuestionIds.isEmpty) {
      return;
    }
    final answerById = <String, String?>{};
    for (var i = 0; i < questionIds.length; i++) {
      answerById[questionIds[i]] = selectedAnswers[i];
    }
    for (final id in wrongQuestionIds) {
      final selected = answerById[id]?.trim().toUpperCase() ?? '';
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
    _notifyProgress();
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
    final encoded = await compute(encodeJsonMap, map);
    await prefs.setString(_kConfigs, encoded);
  }

  Future<void> _persistTests() async {
    final prefs = await SharedPreferences.getInstance();
    final maps = _tests.map((e) => e.toJson()).toList();
    final encoded = await compute(encodeJsonMaps, maps);
    await prefs.setString(_kTests, encoded);
  }

  Future<void> _persistAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final maps = _attempts.map((e) => e.toJson()).toList();
    final encoded = await compute(encodeJsonMaps, maps);
    await prefs.setString(_scopedKey(_kAttempts), encoded);
  }

  Future<void> _persistSolvedQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(_kSolvedQuestions),
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

  Future<void> _persistWrongQuestionStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey(_kWrongQuestionStatuses);
    if (_wrongQuestionStatuses.isEmpty) {
      await prefs.remove(key);
      return;
    }
    final encoded = {
      for (final entry in _wrongQuestionStatuses.entries)
        entry.key: entry.value.name,
    };
    await prefs.setString(key, jsonEncode(encoded));
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
    // Plain JSON maps only — never close over this / Futures in isolate entry.
    final bodies = <Map<String, dynamic>>[
      for (final q in _questions)
        if (_wrongQuestionIds.contains(q.id) &&
            !_sampleSeedQuestionIds.contains(q.id))
          Map<String, dynamic>.from(q.toJson()),
    ];
    if (bodies.isEmpty) {
      await prefs.remove(key);
    } else {
      final encoded = await compute(encodeJsonMaps, bodies);
      await prefs.setString(key, encoded);
    }
  }

  /// API'den doldurulan yanlış gövdelerini diske yaz (yanlış defteri ekranı).
  Future<void> persistWrongQuestionBodiesNow() async {
    await initialize();
    await _persistWrongQuestionBodies();
    _notifyProgress();
  }

  Future<void> _persistQuestions() async {
    // Encode from JSON maps so isolate message stays primitives-only.
    final maps = <Map<String, dynamic>>[
      for (final q in _questions) Map<String, dynamic>.from(q.toJson()),
    ];
    final encoded = await compute(encodeJsonMaps, maps);
    try {
      await LocalDatabase.instance.saveContentQuestionsJson(encoded);
    } catch (e, st) {
      debugPrint('ContentBank SQLite question save: $e\n$st');
      // Fallback: prefs (eski yol).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kQuestions, encoded);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQuestions);
  }

  Future<void> _persistLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final maps = _lessons.map((e) => e.toJson()).toList();
    final encoded = await compute(encodeJsonMaps, maps);
    await prefs.setString(_kLessons, encoded);
  }

  Future<void> _persistSummaryCards() async {
    final prefs = await SharedPreferences.getInstance();
    final maps = _summaryCards.map((e) => e.toJson()).toList();
    final encoded = await compute(encodeJsonMaps, maps);
    await prefs.setString(_kSummaryCards, encoded);
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
