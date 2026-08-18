import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../constants/daily_mini_exam_constants.dart';
import '../constants/savings_constants.dart';
import '../models/content_models.dart';
import '../models/daily_mini_exam_models.dart';
import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/countdown_widget.dart';
import 'auth_service.dart';
import 'content_bank_service.dart';
import 'gamification_service.dart';
import 'premium_service.dart';
import 'question_fetch_service.dart';

enum DailyMiniRankTrend { steady, improved, worsened }

/// Günün mini denemesi: pencere, soru seti, liderlik ve yanlış havuzu.
class DailyMiniExamService extends ChangeNotifier {
  DailyMiniExamService._();
  static final DailyMiniExamService instance = DailyMiniExamService._();

  bool _initialized = false;
  KpssType _kpssType = KpssType.lisans;
  DailyMiniExamSnapshot? _remote;
  List<String> _questionIds = const [];
  List<String?> _answers = const [];
  int _currentIndex = 0;
  int _elapsedSeconds = 0;
  bool _completed = false;
  bool _rankingLocked = false;
  bool _rankRevealActive = false;
  bool _pendingRankingSubmit = false;
  String? _guestFirstDate;
  DailyMiniAttempt? _localAttempt;
  Map<String, List<String>> _monthlyWrongs = {};
  DailyMiniRankTrend _rankTrend = DailyMiniRankTrend.steady;
  int? _snapshotRank;
  int? _snapshotParticipants;

  bool get isInitialized => _initialized;
  DailyMiniRankTrend get rankTrend => _rankTrend;
  DailyMiniExamSnapshot? get remote => _remote;
  bool get rankingLocked =>
      _rankingLocked || _remote?.myAttempt != null;
  bool get rankRevealActive => _rankRevealActive;
  bool get hasSubmittedRanking => rankingLocked || _pendingRankingSubmit;
  bool get completed => hasSubmittedRanking;

  /// Misafir yalnızca ilk gün katılır; sonraki günlerde profil girişi gerekir.
  bool get guestMustSignIn {
    if (!AuthService.instance.isAnonymous) return false;
    if (_remote?.guestLoginRequired == true) return true;
    final first = _guestFirstDate;
    if (first == null || first.isEmpty) return false;
    return first != isoDate(window.examDate);
  }
  DailyMiniAttempt? get attempt => _remote?.myAttempt ?? _localAttempt;
  List<DailyMiniLeaderRow> get leaderboard {
    final remote = _remote?.leaderboard ?? const <DailyMiniLeaderRow>[];
    if (remote.isNotEmpty) return remote;
    final attempt = this.attempt;
    final user = AuthService.instance.user;
    if (attempt == null || user == null || attempt.rank == null) {
      return const [];
    }
    final parts = splitFrostedEmail(user.eposta);
    return [
      DailyMiniLeaderRow(
        rank: attempt.rank!,
        userId: user.id,
        displayName: user.isim,
        emailPrefix: parts.prefix,
        emailRest: parts.rest,
        correct: attempt.correct,
        wrong: attempt.wrong,
        blank: attempt.blank,
        durationSeconds: attempt.durationSeconds,
      ),
    ];
  }
  int get participantCount => _remote?.participantCount ?? 0;
  List<String> get questionIds => List.unmodifiable(_questionIds);
  List<String?> get answers => List<String?>.from(_answers);
  int get currentIndex => _currentIndex;
  int get elapsedSeconds => _elapsedSeconds;
  bool get hasInProgress =>
      !hasSubmittedRanking &&
      _questionIds.isNotEmpty &&
      _answers.any((a) => a != null && a.isNotEmpty);

  /// Sıralama kilitlendikten sonra bile yanıtsız soru varsa quiz sürdürülebilir.
  bool get canResumeQuiz {
    if (_questionIds.isEmpty) return false;
    final hasBlanks = _answers.any((a) => a == null || a.isEmpty);
    if (!hasBlanks) return false;
    return _currentIndex > 0 ||
        _elapsedSeconds > 0 ||
        _answers.any((a) => a != null && a.isNotEmpty);
  }

  DailyMiniExamWindow get window => DailyMiniExamWindow.from(DateTime.now());

  int get monthlyWrongCount {
    final key = _monthKey(DateTime.now());
    return _monthlyWrongs[key]?.length ?? 0;
  }

  String? pdfUpsellMessage({required bool isPremium}) {
    if (isPremium || PremiumService.instance.isPremium) return null;
    if (monthlyWrongCount <= 0) return null;
    return DailyMiniExamConstants.pdfUpsellMessage(
      monthlyPriceTl: SavingsConstants.paywallMonthlyHighlightTl,
    );
  }

  Future<void> initialize({KpssType? kpssType}) async {
    _kpssType = kpssType ?? _kpssType;
    final prefs = await SharedPreferences.getInstance();
    _loadMonthly(prefs);
    _loadProgress(prefs);
    _loadRankSnapshot(prefs);
    _loadRankingFlags(prefs);
    _loadGuestFirstDate(prefs);
    await _stampGuestFirstDateIfNeeded(prefs);
    _initialized = true;
    notifyListeners();
    unawaited(refresh());
    unawaited(_retryPendingRankingSubmitIfNeeded());
  }

  void _loadRankingFlags(SharedPreferences prefs) {
    final today = isoDate(window.examDate);
    if (prefs.getString(_kRankingFlagDate) != today) {
      _rankingLocked = false;
      _pendingRankingSubmit = false;
      return;
    }
    _rankingLocked = prefs.getBool(DailyMiniExamConstants.prefsRankingLocked) ??
        false;
    _pendingRankingSubmit =
        prefs.getBool(DailyMiniExamConstants.prefsPendingRankingSubmit) ??
            false;
  }

  static const _kRankingFlagDate = 'daily_mini_ranking_flag_date_v1';

  void _loadGuestFirstDate(SharedPreferences prefs) {
    _guestFirstDate =
        prefs.getString(DailyMiniExamConstants.prefsGuestFirstDate);
  }

  Future<void> _stampGuestFirstDateIfNeeded(SharedPreferences prefs) async {
    if (!AuthService.instance.isAnonymous) return;
    if (_guestFirstDate != null && _guestFirstDate!.isNotEmpty) return;
    _guestFirstDate = isoDate(window.examDate);
    await prefs.setString(
      DailyMiniExamConstants.prefsGuestFirstDate,
      _guestFirstDate!,
    );
  }

  Future<void> _persistRankingFlags(SharedPreferences prefs) async {
    await prefs.setString(_kRankingFlagDate, isoDate(window.examDate));
    await prefs.setBool(
      DailyMiniExamConstants.prefsRankingLocked,
      _rankingLocked,
    );
    await prefs.setBool(
      DailyMiniExamConstants.prefsPendingRankingSubmit,
      _pendingRankingSubmit,
    );
  }

  Future<void> setKpssType(KpssType type) async {
    if (_kpssType == type) return;
    _kpssType = type;
    _resetDayIfNeeded();
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    _resetDayIfNeeded();
    try {
      final uri = ApiConfig.dailyMiniExamUri(_kpssType.name);
      final response = await http
          .get(uri, headers: AuthService.instance.authHeaders)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          _remote = DailyMiniExamSnapshot.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (_remote!.questionIds.isNotEmpty && !_completed) {
            _questionIds = _remote!.questionIds;
          }
          if (_remote!.myAttempt != null) {
            _completed = true;
            _localAttempt = _remote!.myAttempt;
            _rankingLocked = true;
            _pendingRankingSubmit = false;
          }
        }
      }
    } catch (e) {
      debugPrint('daily mini exam refresh: $e');
    }
    if (_questionIds.isEmpty) {
      _questionIds = _pickLocalIds();
    }
    _ensureAnswerSlots();
    _syncRankSnapshot();
    notifyListeners();
    await _persist();
    await _persistRankSnapshot();
    unawaited(_retryPendingRankingSubmitIfNeeded());
  }

  void _loadRankSnapshot(SharedPreferences prefs) {
    final raw = prefs.getString(DailyMiniExamConstants.prefsRankSnapshot);
    if (raw == null || raw.isEmpty) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (json['date'] != isoDate(window.examDate)) return;
      _snapshotRank = (json['rank'] as num?)?.toInt();
      _snapshotParticipants = (json['participants'] as num?)?.toInt();
      _rankTrend = DailyMiniRankTrend.values.firstWhere(
        (trend) => trend.name == json['trend'],
        orElse: () => DailyMiniRankTrend.steady,
      );
    } catch (_) {}
  }

  void _syncRankSnapshot() {
    if (!completed) {
      _rankTrend = DailyMiniRankTrend.steady;
      return;
    }
    final rank = attempt?.rank;
    final count = participantCount;
    if (rank == null || rank <= 0 || count <= 0) {
      return;
    }
    if (_snapshotRank != null) {
      if (rank > _snapshotRank!) {
        _rankTrend = DailyMiniRankTrend.worsened;
      } else if (rank < _snapshotRank!) {
        _rankTrend = DailyMiniRankTrend.improved;
      }
    } else {
      _rankTrend = DailyMiniRankTrend.steady;
    }
    _snapshotRank = rank;
    _snapshotParticipants = count;
  }

  Future<void> _persistRankSnapshot() async {
    if (_snapshotRank == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      DailyMiniExamConstants.prefsRankSnapshot,
      jsonEncode({
        'date': isoDate(window.examDate),
        'rank': _snapshotRank,
        'participants': _snapshotParticipants,
        'trend': _rankTrend.name,
      }),
    );
  }

  List<QuestionModel> questionsForToday() {
    if (_questionIds.isEmpty) {
      _questionIds = _pickLocalIds();
      _ensureAnswerSlots();
    }
    return ContentBankService.instance.questionsByIds(_questionIds);
  }

  Future<List<QuestionModel>> fetchQuestionsForToday() async {
    if (_questionIds.isEmpty) {
      _questionIds = _pickLocalIds();
      _ensureAnswerSlots();
    }
    return QuestionFetchService.instance.fetchByIds(_questionIds);
  }

  bool get hasEnoughQuestions {
    if (_questionIds.isNotEmpty) return _questionIds.length >= 10;
    return _pickLocalIds().length >= 10;
  }

  String get testId =>
      '${DailyMiniExamConstants.testIdPrefix}${isoDate(window.examDate)}_${_kpssType.name}';

  Future<void> saveProgress({
    required List<String?> answers,
    required int currentIndex,
    required Duration elapsed,
  }) async {
    _answers = List<String?>.from(answers);
    _currentIndex = currentIndex;
    _elapsedSeconds = elapsed.inSeconds;
    await _persist();
    notifyListeners();
  }

  Future<void> recordCompletion({
    required QuizResult result,
    required List<String?> answers,
  }) async {
    await finalizeRanking(result: result, answers: answers);
  }

  /// Tamamlama veya erken çıkış — sıralamaya gönderir (başarılı olunca kilitlenir).
  Future<void> finalizeRanking({
    required QuizResult result,
    required List<String?> answers,
  }) async {
    if (rankingLocked) {
      await saveProgress(
        answers: answers,
        currentIndex: _currentIndex,
        elapsed: result.duration,
      );
      return;
    }

    _completed = true;
    _answers = List<String?>.from(answers);
    _elapsedSeconds = result.duration.inSeconds;
    _localAttempt = DailyMiniAttempt(
      correct: result.correct,
      wrong: result.wrong,
      blank: result.blank,
      total: result.total,
      durationSeconds: result.duration.inSeconds,
      wrongQuestionIds: result.wrongQuestionIds,
    );
    _mergeMonthlyWrongs(result.wrongQuestionIds);
    _rankRevealActive = true;

    await ContentBankService.instance.recordAttempt(
      TestAttemptModel(
        id: 'att_mini_${DateTime.now().millisecondsSinceEpoch}',
        testId: testId,
        topicId: 'turkce_anlam',
        kpssType: _kpssType,
        correct: result.correct,
        wrong: result.wrong,
        blank: result.blank,
        total: result.total,
        duration: result.duration,
        completedAt: DateTime.now(),
      ),
      questionIds: [
        ...result.correctQuestionIds,
        ...result.wrongQuestionIds,
      ],
      wrongQuestionIds: result.wrongQuestionIds,
    );

    await GamificationService.instance.recordTestCompleted(
      correct: result.correct,
      wrong: result.wrong,
      duration: result.duration,
    );

    await _persist();
    notifyListeners();

    final ok = await submitAnswers(result: result, answers: answers);
    if (ok) {
      _rankingLocked = true;
      _pendingRankingSubmit = false;
    } else {
      _pendingRankingSubmit = true;
    }
    _syncRankSnapshot();
    await _persistRankSnapshot();
    await _persist();
    notifyListeners();
  }

  Future<void> _retryPendingRankingSubmitIfNeeded() async {
    if (!_pendingRankingSubmit || _localAttempt == null || rankingLocked) {
      return;
    }
    if (_questionIds.isEmpty) return;
    final answers = List<String?>.from(_answers);
    final result = QuizResult(
      correct: _localAttempt!.correct,
      wrong: _localAttempt!.wrong,
      blank: _localAttempt!.blank,
      total: _localAttempt!.total,
      duration: Duration(seconds: _localAttempt!.durationSeconds),
      completed: _localAttempt!.blank == 0,
      questionIds: _questionIds,
      wrongQuestionIds: _localAttempt!.wrongQuestionIds,
      selectedAnswers: answers,
    );
    final ok = await submitAnswers(result: result, answers: answers);
    if (ok) {
      _rankingLocked = true;
      _pendingRankingSubmit = false;
      _syncRankSnapshot();
      await _persistRankSnapshot();
      await _persist();
      notifyListeners();
    }
  }

  Future<bool> submitAnswers({
    required QuizResult result,
    required List<String?> answers,
  }) async {
    final map = <String, String>{};
    for (var i = 0; i < result.questionIds.length && i < answers.length; i++) {
      final selected = answers[i];
      if (selected != null && selected.isNotEmpty) {
        map[result.questionIds[i]] = selected;
      }
    }
    try {
      final response = await http
          .post(
            ApiConfig.dailyMiniExamUri(_kpssType.name),
            headers: {
              ...AuthService.instance.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'kpss_type': _kpssType.name,
              'answers': map,
              'duration_seconds': result.duration.inSeconds,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          _remote = DailyMiniExamSnapshot.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (_remote!.myAttempt != null) {
            _localAttempt = _remote!.myAttempt;
          }
        }
        notifyListeners();
        await _persist();
        return true;
      }
    } catch (e) {
      debugPrint('daily mini exam submit: $e');
    }
    notifyListeners();
    await _persist();
    return false;
  }

  void clearRankReveal() {
    if (!_rankRevealActive) return;
    _rankRevealActive = false;
    notifyListeners();
  }

  List<String> _pickLocalIds() {
    final bank = ContentBankService.instance;
    final type = _kpssType;
    List<String> idsForSubject(String subjectId) {
      if (bank.hasFullQuestionBank) {
        return bank.questionsForSubject(type, subjectId).map((q) => q.id).toList()
          ..sort();
      }
      return bank.catalogQuestionIdsForSubject(type, subjectId);
    }

    List<String> turkce() {
      if (bank.hasFullQuestionBank) {
        final ids = <String>[];
        for (final topicId in DailyMiniExamConstants.turkceTopicIds) {
          ids.addAll(
            bank.questionsForTopic(type, topicId).map((q) => q.id),
          );
        }
        ids.sort();
        return ids;
      }
      final ids = <String>[];
      for (final topicId in DailyMiniExamConstants.turkceTopicIds) {
        ids.addAll(bank.catalogQuestionIdsForTopic(type, topicId));
      }
      ids.sort();
      return ids;
    }

    final leftovers = bank.hasFullQuestionBank
        ? (bank.allQuestionIds..sort())
        : bank.catalogQuestionIds;

    return pickLocalQuestionIds(
      examDate: window.examDate,
      kpssType: type.name,
      tarihIds: idsForSubject('tarih'),
      cografyaIds: idsForSubject('cografya'),
      vatandaslikIds: idsForSubject('vatandaslik'),
      turkceIds: turkce(),
      leftovers: leftovers,
    );
  }

  void _ensureAnswerSlots() {
    if (_answers.length != _questionIds.length) {
      _answers = List<String?>.filled(_questionIds.length, null);
      _currentIndex = 0;
      _elapsedSeconds = 0;
    }
  }

  void _resetDayIfNeeded() {
    final today = isoDate(window.examDate);
    if (_remote != null && _remote!.examDate != today) {
      _remote = null;
    }
    final storedDate = _storedDate;
    if (storedDate != null && storedDate != today) {
      _questionIds = const [];
      _answers = const [];
      _currentIndex = 0;
      _elapsedSeconds = 0;
      _completed = false;
      _localAttempt = null;
      _rankingLocked = false;
      _rankRevealActive = false;
      _pendingRankingSubmit = false;
      _snapshotRank = null;
      _snapshotParticipants = null;
      _rankTrend = DailyMiniRankTrend.steady;
    }
  }

  String? _storedDate;

  void _loadProgress(SharedPreferences prefs) {
    final raw = prefs.getString(DailyMiniExamConstants.prefsState);
    if (raw == null || raw.isEmpty) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _storedDate = json['date'] as String?;
      final typeName = json['kpssType'] as String?;
      if (typeName != null && typeName != _kpssType.name) return;
      if (_storedDate != isoDate(window.examDate)) return;
      _questionIds = (json['questionIds'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          const [];
      _answers = (json['answers'] as List<dynamic>?)
              ?.map((e) {
                final s = '$e';
                return s.isEmpty ? null : s;
              })
              .toList() ??
          const [];
      _currentIndex = json['currentIndex'] as int? ?? 0;
      _elapsedSeconds = json['elapsedSeconds'] as int? ?? 0;
      _completed = json['completed'] as bool? ?? false;
      _rankingLocked = json['rankingLocked'] as bool? ?? _rankingLocked;
      _pendingRankingSubmit =
          json['pendingRankingSubmit'] as bool? ?? _pendingRankingSubmit;
      if (json['attempt'] is Map) {
        _localAttempt = DailyMiniAttempt.fromJson(
          Map<String, dynamic>.from(json['attempt'] as Map),
        );
      }
    } catch (_) {}
  }

  void _loadMonthly(SharedPreferences prefs) {
    final raw = prefs.getString(DailyMiniExamConstants.prefsMonthlyWrongs);
    if (raw == null || raw.isEmpty) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _monthlyWrongs = json.map(
        (key, value) => MapEntry(
          key,
          (value as List<dynamic>).map((e) => '$e').toList(),
        ),
      );
    } catch (_) {}
  }

  void _mergeMonthlyWrongs(List<String> ids) {
    final key = _monthKey(DateTime.now());
    final set = {...(_monthlyWrongs[key] ?? const <String>[]), ...ids};
    _monthlyWrongs[key] = set.toList();
  }

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    _storedDate = isoDate(window.examDate);
    await prefs.setString(
      DailyMiniExamConstants.prefsState,
      jsonEncode({
        'date': _storedDate,
        'kpssType': _kpssType.name,
        'questionIds': _questionIds,
        'answers': _answers.map((a) => a ?? '').toList(),
        'currentIndex': _currentIndex,
        'elapsedSeconds': _elapsedSeconds,
        'completed': _completed,
        'rankingLocked': _rankingLocked,
        'pendingRankingSubmit': _pendingRankingSubmit,
        if (_localAttempt != null)
          'attempt': {
            'correct': _localAttempt!.correct,
            'wrong': _localAttempt!.wrong,
            'blank': _localAttempt!.blank,
            'total': _localAttempt!.total,
            'durationSeconds': _localAttempt!.durationSeconds,
            'wrongQuestionIds': _localAttempt!.wrongQuestionIds,
            'rank': _localAttempt!.rank,
          },
      }),
    );
    await prefs.setString(
      DailyMiniExamConstants.prefsMonthlyWrongs,
      jsonEncode(_monthlyWrongs),
    );
    await _persistRankingFlags(prefs);
  }
}
