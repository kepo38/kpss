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
  Future<void>? _initFuture;
  KpssType _kpssType = KpssType.lisans;
  DailyMiniExamSnapshot? _remote;
  List<String> _questionIds = const [];
  List<String?> _answers = const [];
  int _currentIndex = 0;
  int _elapsedSeconds = 0;
  bool _completed = false;
  bool _rankingLocked = false;
  bool _rankRevealActive = false;
  int _rankRevealSecondsLeft = 0;
  bool _rankRevealCelebrated = false;
  bool _formallyFinished = false;
  bool _pendingRankingSubmit = false;
  String? _guestFirstDate;
  DailyMiniAttempt? _localAttempt;
  Map<String, List<String>> _monthlyWrongs = {};
  DailyMiniRankTrend _rankTrend = DailyMiniRankTrend.steady;
  int? _snapshotRank;
  int? _snapshotParticipants;
  String? _activeUserId;

  String get _userScopeId => AuthService.instance.user?.id ?? 'unknown';

  String _scopedKey(String base) => '${base}_$_userScopeId';

  bool get isInitialized => _initialized;
  KpssType get kpssType => _kpssType;
  DailyMiniRankTrend get rankTrend => _rankTrend;
  DailyMiniExamSnapshot? get remote => _remote;
  bool get rankingLocked =>
      _rankedAttempt(_remote?.myAttempt) != null ||
      _rankingLocked ||
      (_formallyFinished && _localAttempt != null);
  bool get rankRevealActive => _rankRevealActive;
  bool get rankRevealCountdownVisible =>
      _rankRevealActive && _rankRevealSecondsLeft > 0;
  int get rankRevealSecondsLeft => _rankRevealSecondsLeft;
  bool get rankRevealCelebrated => _rankRevealCelebrated;
  bool get formallyFinished => _formallyFinished;
  /// Bugün bitti / kilitli / gönderim bekliyor — UI asla "Denemeye Başla" göstermemeli.
  bool get hasSubmittedRanking =>
      _formallyFinished ||
      _completed ||
      _rankingLocked ||
      _rankedAttempt(_remote?.myAttempt) != null ||
      (_pendingRankingSubmit && _localAttempt != null) ||
      (_rankRevealActive && _localAttempt != null);
  bool get completed => hasSubmittedRanking;

  /// Misafir yalnızca ilk gün katılır; sonraki günlerde profil girişi gerekir.
  bool get guestMustSignIn {
    if (!AuthService.instance.isAnonymous) return false;
    if (_remote?.guestLoginRequired == true) return true;
    final first = _guestFirstDate;
    if (first == null || first.isEmpty) return false;
    return first != isoDate(window.examDate);
  }

  static DailyMiniAttempt? _rankedAttempt(DailyMiniAttempt? attempt) {
    if (attempt == null || !attempt.countsTowardRanking) return null;
    return attempt;
  }

  DailyMiniAttempt? get attempt {
    final remote = _rankedAttempt(_remote?.myAttempt);
    if (remote != null) return remote;
    if (_remote?.myAttempt != null &&
        (_completed || _formallyFinished || _rankingLocked)) {
      return _remote!.myAttempt;
    }
    if (_pendingRankingSubmit ||
        _rankingLocked ||
        _completed ||
        _formallyFinished) {
      // Bitmiş denemede boş puanlı yerel deneme de kalsın (kürsü/pending UI).
      return _localAttempt;
    }
    return null;
  }
  List<DailyMiniLeaderRow> get leaderboard {
    final remote = _remote?.leaderboard ?? const <DailyMiniLeaderRow>[];
    if (remote.isNotEmpty) return _withoutDemoLeaders(remote);
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

  /// seed_daily_mini_demo kayıtları — eski API yanıtlarında da gizlenir.
  static bool isDemoLeaderRow(DailyMiniLeaderRow row) {
    if (row.displayName.toLowerCase().startsWith('demo ')) return true;
    return row.emailRest.toLowerCase().contains('@hedefkamu.app') &&
        row.emailPrefix.toLowerCase().startsWith('dem');
  }

  static List<DailyMiniLeaderRow> _withoutDemoLeaders(
    List<DailyMiniLeaderRow> rows,
  ) {
    return rows.where((row) => !isDemoLeaderRow(row)).toList();
  }

  int _demoLeaderCount(List<DailyMiniLeaderRow> rows) =>
      rows.where(isDemoLeaderRow).length;

  /// Paylaşım ve kürsü rozeti için gerçek katılımcı sayısı.
  int get visibleParticipantCount {
    final remote = _remote;
    if (remote != null) {
      final demoInBoard = _demoLeaderCount(remote.leaderboard);
      final boardCount = remote.leaderboardParticipantCount;
      if (boardCount > 0) {
        return (boardCount - demoInBoard).clamp(0, boardCount);
      }
      final todayCount = remote.participantCount;
      if (todayCount > 0) {
        return (todayCount - demoInBoard).clamp(0, todayCount);
      }
    }
    if (leaderboard.isNotEmpty) return leaderboard.length;
    return participantCount;
  }

  /// Sıra: attempt → kürsü satırı.
  int? rankForCurrentUser() {
    final attemptRank = attempt?.rank;
    if (attemptRank != null && attemptRank > 0) return attemptRank;
    final userId = AuthService.instance.user?.id;
    if (userId == null) return null;
    for (final row in leaderboard) {
      if (row.userId == userId && row.rank > 0) return row.rank;
    }
    return null;
  }

  bool get canShareRank {
    final rank = rankForCurrentUser();
    final count = visibleParticipantCount;
    return rank != null && rank > 0 && count > 0;
  }
  int get participantCount => _remote?.participantCount ?? 0;
  int get podiumParticipantCount {
    final remoteCount = _remote?.leaderboardParticipantCount ?? 0;
    if (remoteCount > 0) {
      final demoInBoard =
          _demoLeaderCount(_remote?.leaderboard ?? const []);
      return (remoteCount - demoInBoard).clamp(0, remoteCount);
    }
    if (window.isPreOpen) return 0;
    return visibleParticipantCount;
  }
  bool get showingYesterdayPodium => window.isPreOpen;
  List<String> get questionIds => List.unmodifiable(_questionIds);
  List<String?> get answers => List<String?>.from(_answers);
  int get currentIndex => _currentIndex;
  int get elapsedSeconds => _elapsedSeconds;
  bool get hasInProgress =>
      !hasSubmittedRanking &&
      _questionIds.isNotEmpty &&
      _answers.any((a) => a != null && a.isNotEmpty);

  /// Erken çıkış + kısmi cevap: devam edilebilir. Onaylı «Bitir»: devam yok.
  bool get canResumeQuiz {
    if (_formallyFinished) return false;
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
    final typeChanged = kpssType != null && kpssType != _kpssType;
    if (kpssType != null) _kpssType = kpssType;

    if (!_initialized) {
      await (_initFuture ??= _initializeBody());
      return;
    }

    if (typeChanged) {
      _resetDayIfNeeded();
      notifyListeners();
      await refresh();
    }
  }

  Future<void> _initializeBody() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyPrefsIfNeeded(prefs);
    _loadMonthly(prefs);
    _loadProgress(prefs);
    _loadRankSnapshot(prefs);
    _loadRankingFlags(prefs);
    _loadGuestFirstDate(prefs);
    await _stampGuestFirstDateIfNeeded(prefs);
    _activeUserId = _userScopeId;
    _initialized = true;
    notifyListeners();
    unawaited(refresh());
    unawaited(_retryPendingRankingSubmitIfNeeded());
  }

  Future<void> setKpssType(KpssType type) async {
    await initialize(kpssType: type);
    if (_kpssType == type) return;
    _kpssType = type;
    _resetDayIfNeeded();
    notifyListeners();
    await refresh();
  }

  void _loadRankingFlags(SharedPreferences prefs) {
    final today = isoDate(window.examDate);
    if (prefs.getString(_scopedKey(_kRankingFlagDate)) != today) {
      // Progress zaten bugünkü tamamlanmayı yüklediyse bayrakları silme
      // (eski kurulum / yarış: flag date yok ama state JSON var).
      if (_storedDate == today &&
          (_rankingLocked ||
              _completed ||
              _formallyFinished ||
              _pendingRankingSubmit ||
              _localAttempt != null)) {
        return;
      }
      _rankingLocked = false;
      _pendingRankingSubmit = false;
      return;
    }
    _rankingLocked =
        prefs.getBool(_scopedKey(DailyMiniExamConstants.prefsRankingLocked)) ??
            _rankingLocked;
    _pendingRankingSubmit = prefs.getBool(
          _scopedKey(DailyMiniExamConstants.prefsPendingRankingSubmit),
        ) ??
        _pendingRankingSubmit;
  }

  static const _kRankingFlagDate = 'daily_mini_ranking_flag_date_v1';

  void _loadGuestFirstDate(SharedPreferences prefs) {
    _guestFirstDate =
        prefs.getString(_scopedKey(DailyMiniExamConstants.prefsGuestFirstDate));
  }

  Future<void> _stampGuestFirstDateIfNeeded(SharedPreferences prefs) async {
    if (!AuthService.instance.isAnonymous) return;
    if (_guestFirstDate != null && _guestFirstDate!.isNotEmpty) return;
    _guestFirstDate = isoDate(window.examDate);
    await prefs.setString(
      _scopedKey(DailyMiniExamConstants.prefsGuestFirstDate),
      _guestFirstDate!,
    );
  }

  Future<void> _persistRankingFlags(SharedPreferences prefs) async {
    await prefs.setString(_scopedKey(_kRankingFlagDate), isoDate(window.examDate));
    await prefs.setBool(
      _scopedKey(DailyMiniExamConstants.prefsRankingLocked),
      _rankingLocked,
    );
    await prefs.setBool(
      _scopedKey(DailyMiniExamConstants.prefsPendingRankingSubmit),
      _pendingRankingSubmit,
    );
  }

  /// Oturum değişince (çıkış, misafir→Google) o kullanıcının durumunu yükle.
  Future<void> onAuthSessionChanged() async {
    if (!_initialized) return;
    final userId = _userScopeId;
    if (_activeUserId != userId) {
      await _reloadForCurrentUser();
    }
    await refresh();
    await _retryPendingRankingSubmitIfNeeded();
    notifyListeners();
  }

  void _clearSessionMemory() {
    _remote = null;
    _questionIds = const [];
    _answers = const [];
    _currentIndex = 0;
    _elapsedSeconds = 0;
    _completed = false;
    _rankingLocked = false;
    _rankRevealActive = false;
    _rankRevealSecondsLeft = 0;
    _rankRevealCelebrated = false;
    _formallyFinished = false;
    _pendingRankingSubmit = false;
    _localAttempt = null;
    _snapshotRank = null;
    _snapshotParticipants = null;
    _rankTrend = DailyMiniRankTrend.steady;
    _guestFirstDate = null;
    _storedDate = null;
  }

  Future<void> _reloadForCurrentUser() async {
    _clearSessionMemory();
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyPrefsIfNeeded(prefs);
    _loadProgress(prefs);
    _loadRankSnapshot(prefs);
    _loadRankingFlags(prefs);
    _loadGuestFirstDate(prefs);
    _activeUserId = _userScopeId;
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
          final remoteAttempt = _remote!.myAttempt;
          final rankedRemote = _rankedAttempt(remoteAttempt);
          if (rankedRemote != null) {
            _completed = true;
            _formallyFinished = true;
            _localAttempt = rankedRemote;
            _rankingLocked = true;
            _pendingRankingSubmit = false;
          } else if (remoteAttempt != null &&
              (_completed ||
                  _formallyFinished ||
                  _rankingLocked ||
                  _pendingRankingSubmit)) {
            // Sunucu denemeyi döndürdü ama skor filtresi kaçırdı — yine tamamlandı.
            _completed = true;
            _formallyFinished = true;
            _localAttempt = remoteAttempt;
            _rankingLocked = true;
            _pendingRankingSubmit = false;
          } else if (!_pendingRankingSubmit &&
              !_rankRevealActive &&
              !_completed &&
              !_formallyFinished &&
              !_rankingLocked) {
            // Bitirme sonrasi 10 sn sayac / yerel deneme surerken GET yarisi silmesin.
            _localAttempt = null;
            _completed = false;
            _rankingLocked = false;
            _formallyFinished = false;
            _rankRevealActive = false;
            _rankRevealSecondsLeft = 0;
            _rankRevealCelebrated = false;
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
    final raw = prefs.getString(_scopedKey(DailyMiniExamConstants.prefsRankSnapshot));
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
      _scopedKey(DailyMiniExamConstants.prefsRankSnapshot),
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

  Future<void> markFormallyFinished() async {
    if (_formallyFinished) return;
    _formallyFinished = true;
    await _persist();
    notifyListeners();
  }

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
      if (result.completed) {
        await markFormallyFinished();
      }
      return;
    }

    final answered = answers.any((a) => a != null && a.isNotEmpty);
    if (!answered) {
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
    if (result.completed) {
      _formallyFinished = true;
    }
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
    _rankRevealSecondsLeft = 10;
    _rankRevealCelebrated = false;
    // Kürsü + sayaç hemen görünsün; refresh yarışı da silmesin.
    _pendingRankingSubmit = true;
    notifyListeners();

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
      selectedAnswers: result.selectedAnswers,
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
      // Sıra ilk kez geldiyse (misafir→Google sonrası vb.) sayaçsız göster.
      if (_localAttempt?.rank != null &&
          _rankRevealSecondsLeft <= 0 &&
          !_rankRevealActive) {
        notifyListeners();
      }
    } else {
      _pendingRankingSubmit = true;
    }
    _syncRankSnapshot();
    await _persistRankSnapshot();
    await _persist();
    notifyListeners();
  }

  Future<void> _retryPendingRankingSubmitIfNeeded() async {
    if (!_pendingRankingSubmit || _rankedAttempt(_localAttempt) == null || rankingLocked) {
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
      // Bekleyen gönderim başarılı olsa bile 10 sn sıra açılışını koru.
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
    if (!_rankRevealActive && _rankRevealSecondsLeft <= 0) return;
    _rankRevealActive = false;
    _rankRevealSecondsLeft = 0;
    unawaited(_persist());
    notifyListeners();
  }

  /// Konfeti yalnızca sıralama ilk kez açıldığında — gün başına bir kez.
  Future<void> markRankRevealCelebrated() async {
    if (_rankRevealCelebrated) return;
    _rankRevealCelebrated = true;
    await _persist();
    notifyListeners();
  }

  void tickRankRevealCountdown() {
    if (!_rankRevealActive || _rankRevealSecondsLeft <= 0) return;
    _rankRevealSecondsLeft--;
    if (_rankRevealSecondsLeft <= 0) {
      _rankRevealActive = false;
    }
    unawaited(_persist());
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
      _rankRevealSecondsLeft = 0;
      _rankRevealCelebrated = false;
      _formallyFinished = false;
      _pendingRankingSubmit = false;
      _snapshotRank = null;
      _snapshotParticipants = null;
      _rankTrend = DailyMiniRankTrend.steady;
    }
  }

  String? _storedDate;

  void _loadProgress(SharedPreferences prefs) {
    final raw = prefs.getString(_scopedKey(DailyMiniExamConstants.prefsState));
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
      _rankRevealActive =
          json['rankRevealActive'] as bool? ?? _rankRevealActive;
      _rankRevealSecondsLeft =
          json['rankRevealSecondsLeft'] as int? ?? _rankRevealSecondsLeft;
      _rankRevealCelebrated =
          json['rankRevealCelebrated'] as bool? ?? _rankRevealCelebrated;
      _formallyFinished =
          json['formallyFinished'] as bool? ?? _formallyFinished;
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
    final raw =
        prefs.getString(_scopedKey(DailyMiniExamConstants.prefsMonthlyWrongs));
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

  Future<void> _migrateLegacyPrefsIfNeeded(SharedPreferences prefs) async {
    final pairs = <String, String>{
      DailyMiniExamConstants.prefsMonthlyWrongs:
          _scopedKey(DailyMiniExamConstants.prefsMonthlyWrongs),
      DailyMiniExamConstants.prefsGuestFirstDate:
          _scopedKey(DailyMiniExamConstants.prefsGuestFirstDate),
    };
    for (final entry in pairs.entries) {
      if (prefs.containsKey(entry.value)) continue;
      final legacy = prefs.get(entry.key);
      if (legacy == null) continue;
      if (legacy is String) {
        await prefs.setString(entry.value, legacy);
      } else if (legacy is bool) {
        await prefs.setBool(entry.value, legacy);
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    _storedDate = isoDate(window.examDate);
    await prefs.setString(
      _scopedKey(DailyMiniExamConstants.prefsState),
      jsonEncode({
        'date': _storedDate,
        'kpssType': _kpssType.name,
        'questionIds': _questionIds,
        'answers': _answers.map((a) => a ?? '').toList(),
        'currentIndex': _currentIndex,
        'elapsedSeconds': _elapsedSeconds,
        'completed': _completed,
        'rankingLocked': _rankingLocked,
        'rankRevealActive': _rankRevealActive,
        'rankRevealSecondsLeft': _rankRevealSecondsLeft,
        'rankRevealCelebrated': _rankRevealCelebrated,
        'formallyFinished': _formallyFinished,
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
      _scopedKey(DailyMiniExamConstants.prefsMonthlyWrongs),
      jsonEncode(_monthlyWrongs),
    );
    await _persistRankingFlags(prefs);
  }
}
