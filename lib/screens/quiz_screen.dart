import 'dart:async';

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/daily_mini_exam_constants.dart';
import '../constants/tg_exam_constants.dart';
import '../theme/tg_exam_theme.dart';
import '../layout/app_breakpoints.dart';
import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../services/ad_manager.dart';
import '../services/ad_constants.dart';
import '../services/ad_service.dart';
import '../services/answer_feedback_service.dart';
import '../services/app_config_service.dart';
import '../services/content_bank_service.dart';
import '../services/daily_mini_exam_service.dart';
import '../services/favorites_service.dart';
import '../services/gamification_service.dart';
import '../services/auth_service.dart';
import '../services/last_study_session_service.dart';
import '../services/premium_service.dart';
import '../services/question_error_report_service.dart';
import '../services/question_attempt_service.dart';
import '../services/question_note_service.dart';
import '../services/tg_exam_service.dart';
import '../services/wrong_notebook_drawing_service.dart';
import '../services/question_rating_service.dart';
import '../services/question_view_service.dart';
import '../theme/app_theme.dart';
import '../theme/exam_typography.dart';
import '../utils/solution_preview.dart';
import '../utils/tg_exam_subject_filter.dart';
import '../utils/wrong_notebook_session_navigation.dart';
import '../models/wrong_notebook_session_filter.dart';
import '../widgets/app_back_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/embossed_app_bar_title.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/cached_remote_image.dart';
import '../widgets/exam_text/exam_option_view.dart';
import '../widgets/exam_text/exam_scenario_passage_view.dart';
import '../widgets/exam_text/exam_solution_view.dart';
import '../widgets/exam_text/option_column_layout.dart';
import '../widgets/formatted_text.dart';
import '../widgets/question_error_report_button.dart';
import '../widgets/question_rating_bar.dart';
import '../widgets/osym_badge.dart';
import '../widgets/question_stem_content.dart';
import '../widgets/tg_exam/tg_section_filter_toggle.dart';
import '../widgets/tg_exam/tg_subject_filter_bar.dart';
import '../widgets/quiz_drawing_overlay.dart';
import '../widgets/quiz_zoom_daily_hint.dart';
import '../widgets/quiz_zoom_viewport.dart';
import '../widgets/quiz_question_note_card.dart';
import '../widgets/quiz_take_note_button.dart';
import '../widgets/quiz_wrong_notebook_banner.dart';
import '../widgets/pro_upsell_sheet.dart';
import '../widgets/shareable_result_card.dart';
/// Test / soru çözme ekranı — süre, navigator, favori.
class QuizScreen extends StatefulWidget {
  final String title;
  final List<QuestionModel> questions;
  final int timeLimitMinutes;
  final int initialIndex;
  final List<String?>? initialAnswers;
  final Duration initialElapsed;
  final QuizResumeMeta? resumeMeta;
  final bool skipResultDialog;

  /// Yanlış Defterim kartından tek soru inceleme — süre/1/1 yok, not alınır.
  final bool fromWrongNotebook;

  /// Defter pratiği gibi oturumlarda «defterde kayıtlı» uyarısını basma.
  final bool suppressWrongNotebookHint;

  /// Benzer soru seti gibi oturumlarda üstte Soru X/Y gösterme.
  final bool hideQuestionCounter;

  /// Günün Denemesi gibi tanıtım oturumları — çözüm/banner/bitiş reklamı yok.
  final bool adFreeExperience;
  final bool dailyMiniRankingMode;
  final bool tgExamMode;
  final bool tgExamSolutionReview;
  /// Açık TG oturumundan devam — initState'te gereksiz kayıt uyarısı gösterme.
  final bool tgExamResume;
  final int? tgExamId;
  final String? statisticsTestId;
  final Future<bool> Function({
    required List<String?> answers,
    required int currentIndex,
    required Duration elapsed,
  })? onProgress;

  const QuizScreen({
    super.key,
    required this.title,
    required this.questions,
    this.timeLimitMinutes = 0,
    this.initialIndex = 0,
    this.initialAnswers,
    this.initialElapsed = Duration.zero,
    this.resumeMeta,
    this.skipResultDialog = false,
    this.fromWrongNotebook = false,
    this.suppressWrongNotebookHint = false,
    this.hideQuestionCounter = false,
    this.adFreeExperience = false,
    this.dailyMiniRankingMode = false,
    this.tgExamMode = false,
    this.tgExamSolutionReview = false,
    this.tgExamResume = false,
    this.tgExamId,
    this.statisticsTestId,
    this.onProgress,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  String? _selectedAnswer;
  bool _showingSolution = false;
  late DateTime _startedAt;
  late final List<String?> _answers;
  late final bool _isCountdown;
  /// Timer UI only — do not drive full-screen setState from the ticker.
  late final ValueNotifier<Duration> _durationNotifier;
  Timer? _ticker;
  bool _timerPaused = false;
  Duration _frozenElapsed = Duration.zero;
  bool _timeUpHandled = false;
  bool _tgTenMinuteWarningPlayed = false;
  bool _isFinishing = false;
  DateTime? _lastProgressErrorAt;
  QuestionRatingSummary? _ratingSummary;
  String? _ratingQuestionId;
  bool _ratingLoading = false;
  bool _ratingSaving = false;
  bool _solutionUnlocking = false;
  bool _errorReported = false;
  bool _errorReportLoading = false;
  bool _errorDailyLimitReached = false;
  final Map<String, QuestionAttemptSummary> _attemptSummaries = {};
  final Set<String> _viewedIds = {};
  final Map<String, int> _viewCounts = {};
  /// Soru açılışında / cevapta güncellenen canlı başarı oranı (0–1 veya 0–100).
  final Map<String, double> _liveCorrectRates = {};
  final Map<String, List<QuizStroke>> _drawings = {};
  bool _drawingEnabled = false;
  bool _noteCardOpen = false;
  bool _showWrongNotebookHint = false;
  Timer? _wrongNotebookHintTimer;
  Timer? _wrongNotebookHintDelayTimer;
  static const _maxStrokesPerQuestion = 80;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chipScrollController = ScrollController();
  final TransformationController _contentZoom = TransformationController();
  TgSectionFilter _tgSectionFilter = TgSectionFilter.all;
  String? _tgSubjectKey;

  late final AnimationController _flashCtrl;
  late final Animation<double> _flashOpacity;
  Color _flashColor = const Color(0xFF34D399);

  static const _correctGreen = Color(0xFF34D399);
  static const _wrongRed = Color(0xFFF87171);
  static const _answeredWrongBurgundy = Color(0xFF9F1239);
  static const _quizContentPaddingLeft = 20.0;
  static const _quizContentPaddingTop = 18.0;
  static const _previousBlue = Color(0xFF60A5FA);

  bool get _tgLiveExam =>
      widget.tgExamMode && !widget.tgExamSolutionReview;

  Color get _quizAccent =>
      _tgLiveExam ? TgExamTheme.crimsonBright : AppTheme.champagne;

  Color get _quizAccentLight =>
      _tgLiveExam ? TgExamTheme.accentLight : AppTheme.champagneLight;

  Color get _quizInk => _tgLiveExam ? TgExamTheme.ink : AppTheme.ink;

  Color get _quizInkSoft => _tgLiveExam ? TgExamTheme.inkSoft : AppTheme.inkSoft;

  List<int> _visibleQuestionIndices() {
    if (!_tgLiveExam) {
      return List.generate(widget.questions.length, (i) => i);
    }
    return tgVisibleQuestionIndices(
      questions: widget.questions,
      section: _tgSectionFilter,
      subjectKey: _tgSubjectKey,
    );
  }

  void _onTgSectionChanged(TgSectionFilter next) {
    setState(() {
      _tgSectionFilter = next;
      _tgSubjectKey = null;
    });
    _syncCurrentToVisibleFilter();
  }

  void _onTgSubjectChanged(String? next) {
    setState(() => _tgSubjectKey = next);
    _syncCurrentToVisibleFilter();
  }

  void _syncCurrentToVisibleFilter() {
    final visible = _visibleQuestionIndices();
    if (visible.isEmpty) return;
    if (!visible.contains(_currentIndex)) {
      _goTo(visible.first);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollChipIntoView(_currentIndex);
      });
    }
  }

  void _scrollChipIntoView(int questionIndex) {
    if (!_chipScrollController.hasClients) return;
    final visible = _visibleQuestionIndices();
    final listIndex = visible.indexOf(questionIndex);
    if (listIndex < 0) return;
    const chipWidth = 34.0;
    const separator = 6.0;
    const horizontalPadding = 16.0;
    final itemStride = chipWidth + separator;
    final viewport = _chipScrollController.position.viewportDimension;
    final targetCenter =
        horizontalPadding + listIndex * itemStride + chipWidth / 2;
    final offset =
        (targetCenter - viewport / 2).clamp(0.0, _chipScrollController.position.maxScrollExtent);
    _chipScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.42), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 0.42, end: 0), weight: 82),
    ]).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));

    if (widget.questions.isEmpty) {
      _currentIndex = 0;
      _answers = <String?>[];
      _selectedAnswer = null;
      _startedAt = DateTime.now();
      _frozenElapsed = Duration.zero;
      _isCountdown = false;
      _durationNotifier = ValueNotifier(Duration.zero);
      _timerPaused = true;
      return;
    }

    final maxIdx = widget.questions.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIdx);
    final resume = widget.initialAnswers;
    if (resume != null && resume.length == widget.questions.length) {
      _answers = List<String?>.from(resume);
    } else {
      _answers = List<String?>.filled(widget.questions.length, null);
    }
    _selectedAnswer = _answers[_currentIndex];
    final elapsed = widget.initialElapsed.isNegative
        ? Duration.zero
        : widget.initialElapsed;
    _startedAt = DateTime.now().subtract(elapsed);
    _frozenElapsed = elapsed;
    _isCountdown = _countdownLimitMinutes > 0;
    Duration initialDisplay;
    if (_isCountdown) {
      final limit = Duration(minutes: _countdownLimitMinutes);
      final left = limit - elapsed;
      initialDisplay = left.isNegative ? Duration.zero : left;
    } else {
      initialDisplay = elapsed;
    }
    _durationNotifier = ValueNotifier(initialDisplay);
    // Devam edilen oturumda mevcut soru cevaplıysa süre bekletilir.
    _timerPaused = widget.tgExamMode
        ? false
        : (_selectedAnswer != null || widget.fromWrongNotebook);
    FavoritesService.instance.initialize();
    QuestionNoteService.instance.initialize();
    if (widget.fromWrongNotebook) {
      unawaited(_loadPersistedDrawings(_currentQuestion.id));
    }
    AnswerFeedbackService.instance.ensureReady();
    AdManager.instance.startTestSession(
      adFreeExperience: widget.adFreeExperience,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_selectedAnswer != null) unawaited(_loadRating());
    unawaited(_loadErrorReportState());
    unawaited(_recordCurrentView());
    if (widget.tgExamResume) {
      // Devam: sunucu zaten cevapları biliyor; ilk karede sessiz senkron.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_persistProgress(suppressError: true));
      });
    } else {
      unawaited(_persistProgress());
    }
    if (widget.tgExamSolutionReview && widget.questions.isNotEmpty) {
      _showingSolution = true;
    }
    ContentBankService.instance.addListener(_onContentBankUpdated);
    unawaited(_bootstrapWrongNotebookHint());
    _resetScrollToTop();
  }

  Future<void> _bootstrapWrongNotebookHint() async {
    await ContentBankService.instance.initialize();
    if (!mounted) return;
    _syncWrongNotebookHint(rebuild: true);
  }

  void _onContentBankUpdated() {
    if (!mounted ||
        widget.fromWrongNotebook ||
        widget.suppressWrongNotebookHint) {
      return;
    }
    _syncWrongNotebookHint(rebuild: true);
  }

  void _syncWrongNotebookHint({bool rebuild = false}) {
    final wasVisible = _showWrongNotebookHint;
    _refreshWrongNotebookHint();
    if (rebuild && wasVisible != _showWrongNotebookHint && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ContentBankService.instance.removeListener(_onContentBankUpdated);
    _wrongNotebookHintTimer?.cancel();
    _wrongNotebookHintDelayTimer?.cancel();
    _ticker?.cancel();
    _durationNotifier.dispose();
    _flashCtrl.dispose();
    _scrollController.dispose();
    _chipScrollController.dispose();
    _contentZoom.dispose();
    AdManager.instance.endTestSession();
    super.dispose();
  }

  Duration get _elapsedNow =>
      _timerPaused ? _frozenElapsed : DateTime.now().difference(_startedAt);

  /// Geri sayım süresi (dakika); TG dahil widget değerini kullanır.
  int get _countdownLimitMinutes => widget.timeLimitMinutes;

  bool get _usesCountdown => _countdownLimitMinutes > 0;

  void _syncDisplayFromElapsed(Duration elapsed) {
    final Duration next;
    if (_usesCountdown) {
      final limit = Duration(minutes: _countdownLimitMinutes);
      final left = limit - elapsed;
      next = left.isNegative ? Duration.zero : left;
    } else {
      next = elapsed;
    }
    if (_durationNotifier.value != next) {
      _durationNotifier.value = next;
    }
  }

  void _pauseTimer() {
    if (_timerPaused) return;
    _frozenElapsed = DateTime.now().difference(_startedAt);
    _timerPaused = true;
    _syncDisplayFromElapsed(_frozenElapsed);
  }

  void _resumeTimer() {
    if (!_timerPaused) return;
    _startedAt = DateTime.now().subtract(_frozenElapsed);
    _timerPaused = false;
  }

  /// TG denemede süre cevap sonrası da akar; diğer modlarda cevaplı soruda bekler.
  void _syncTimerForCurrentQuestion() {
    if (widget.fromWrongNotebook || widget.tgExamSolutionReview) {
      _pauseTimer();
      return;
    }
    if (widget.tgExamMode) {
      _resumeTimer();
      return;
    }
    if (_selectedAnswer != null) {
      _pauseTimer();
    } else {
      _resumeTimer();
    }
  }

  void _refreshWrongNotebookHint() {
    _wrongNotebookHintTimer?.cancel();
    _wrongNotebookHintDelayTimer?.cancel();
    _showWrongNotebookHint = false;
    if (widget.questions.isEmpty) return;
    final hide = widget.fromWrongNotebook || widget.suppressWrongNotebookHint;
    final inNotebook = !hide &&
        ContentBankService.instance.isInWrongNotebook(_currentQuestion.id);
    if (!inNotebook) return;
    // Soru geldikten 1 sn sonra yumuşak görünüm.
    _wrongNotebookHintDelayTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _showWrongNotebookHint = true);
      _wrongNotebookHintTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _showWrongNotebookHint = false);
      });
    });
  }

  void _openQuestionNote() {
    if (_isFinishing) return;
    setState(() => _noteCardOpen = true);
  }

  Future<void> _saveQuestionNote(String text) async {
    await QuestionNoteService.instance.save(_currentQuestion.id, text);
    if (mounted) setState(() {});
  }

  Future<void> _persistProgress({bool suppressError = false}) async {
    if (widget.questions.isEmpty || _isFinishing) return;
    _answers[_currentIndex] = _selectedAnswer;
    final meta = widget.resumeMeta;
    if (meta != null) {
      await LastStudySessionService.instance.recordQuizProgress(
        meta: meta,
        title: widget.title,
        questionIds: widget.questions.map((q) => q.id).toList(),
        answers: _answers,
        currentIndex: _currentIndex,
        timeLimitMinutes: widget.timeLimitMinutes,
        elapsed: _elapsedNow,
      );
    }
    final progress = widget.onProgress;
    if (progress == null) return;
    final ok = await progress(
      answers: _answers,
      currentIndex: _currentIndex,
      elapsed: _elapsedNow,
    );
    if (!ok &&
        widget.tgExamMode &&
        !widget.tgExamSolutionReview &&
        !suppressError &&
        mounted) {
      _maybeWarnProgressSaveFailed();
    }
  }

  void _maybeWarnProgressSaveFailed() {
    final now = DateTime.now();
    final last = _lastProgressErrorAt;
    if (last != null && now.difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _lastProgressErrorAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'İlerleme kaydedilemedi. İnterneti kontrol edin — cevaplar kaybolabilir.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _selectAnswer(String key) {
    if (widget.tgExamSolutionReview || widget.fromWrongNotebook) return;
    if (_selectedAnswer == key) return;
    final isCorrect = key == _currentQuestion.dogruCevap;
    setState(() {
      _selectedAnswer = key;
      _answers[_currentIndex] = key;
      if (!widget.tgExamMode) {
        _pauseTimer();
      }
    });
    if (widget.tgExamMode) {
      unawaited(_persistProgress());
      return;
    }
    unawaited(_loadRating());
    unawaited(_submitQuestionAttempt(key));
    unawaited(_persistProgress());
    _flashColor = isCorrect ? _correctGreen : _wrongRed;
    _flashCtrl.forward(from: 0);
    if (isCorrect) {
      AnswerFeedbackService.instance.playCorrect();
    } else {
      AnswerFeedbackService.instance.playWrong();
    }
  }

  Future<void> _submitQuestionAttempt(String selectedOption) async {
    final testId = widget.statisticsTestId ?? widget.resumeMeta?.testId;
    if (testId == null || testId.isEmpty) return;
    final questionId = _currentQuestion.id;
    if (ContentBankService.instance.isStatLockedForQuestion(questionId)) {
      return;
    }
    final summary = await QuestionAttemptService.instance.submitQuestion(
      testId: testId,
      questionId: questionId,
      selectedOption: selectedOption,
    );
    if (!mounted || summary == null || _currentQuestion.id != questionId) {
      return;
    }
    setState(() {
      _attemptSummaries[questionId] = summary;
      final rate = summary.correctRate;
      if (rate != null) {
        _liveCorrectRates[questionId] = rate;
      }
    });
  }

  void _tick() {
    if (!mounted || _timerPaused || widget.questions.isEmpty) return;
    final elapsed = DateTime.now().difference(_startedAt);
    if (_isCountdown) {
      final limit = Duration(minutes: _countdownLimitMinutes);
      final left = limit - elapsed;
      _syncDisplayFromElapsed(elapsed);
      if (widget.tgExamMode &&
          !widget.tgExamSolutionReview &&
          !_tgTenMinuteWarningPlayed &&
          left <= const Duration(minutes: TgExamConstants.warningBeforeEndMinutes) &&
          left > Duration.zero) {
        _tgTenMinuteWarningPlayed = true;
        unawaited(AnswerFeedbackService.instance.playExamTimeWarning());
      }
      if (left <= Duration.zero && !_timeUpHandled) {
        _timeUpHandled = true;
        _onTimeUp();
      }
    } else {
      _syncDisplayFromElapsed(elapsed);
    }
  }

  Future<void> _onTimeUp() async {
    if (!mounted) return;
    if (widget.tgExamMode) {
      if (mounted) unawaited(_finishTest());
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.inkSoft,
        title: const Text('Süre bitti', style: TextStyle(color: Colors.white)),
        content: Text(
          'Test süresi doldu. Sonuçlarınız kaydedilecek.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
    if (mounted) unawaited(_finishTest());
  }

  QuestionModel get _currentQuestion => widget.questions[_currentIndex];

  String get _resultHeading {
    final topic =
        widget.questions.isEmpty ? '' : widget.questions.first.konuAdi.trim();
    if (topic.isNotEmpty) return topic;
    return widget.title.trim().isEmpty ? 'Test Sonucu' : widget.title;
  }

  String _emotionalFeedback(QuizResult result) {
    final pct = result.accuracy;
    if (pct >= 0.9) {
      return 'Muazzam! Kamuya bir adım daha yaklaştın.';
    }
    if (pct >= 0.5) {
      return 'Güzel ilerleme, eksikleri kapatma zamanı.';
    }
    return 'Asla pes etme. Yanlışlar en büyük öğretmendir.';
  }

  /// Doğru cevaplayan oranı — `Başarı: %49`. Veri yoksa `Başarı: —`.
  double? _successRatePercent() {
    final live = _optionPercentages;
    if (live != null && live.isNotEmpty) {
      final correctKey = _currentQuestion.dogruCevap.trim().toUpperCase();
      double? livePct = live[correctKey] ?? live[_currentQuestion.dogruCevap];
      if (livePct == null) {
        for (final entry in live.entries) {
          if (entry.key.trim().toUpperCase() == correctKey) {
            livePct = entry.value;
            break;
          }
        }
      }
      if (livePct != null) {
        return livePct <= 1.0 ? livePct * 100 : livePct;
      }
    }

    final summaryRate = _attemptSummaries[_currentQuestion.id]?.correctRate;
    if (summaryRate != null) {
      return summaryRate <= 1.0 ? summaryRate * 100 : summaryRate;
    }

    final refreshed = _liveCorrectRates[_currentQuestion.id];
    if (refreshed != null) {
      return refreshed <= 1.0 ? refreshed * 100 : refreshed;
    }

    final rate = _currentQuestion.correctRate;
    if (rate != null) {
      return rate <= 1.0 ? rate * 100 : rate;
    }

    return null;
  }

  String _successRateLabel() {
    final pct = _successRatePercent();
    if (pct != null) return 'Başarı: %${pct.round()}';
    // Henüz istatistik yok — örnek gösterim.
    return 'Başarı: %70';
  }

  /// Dikey gösterge; veri yokken örnek %70.
  double _successRateMeterValue() {
    final pct = _successRatePercent();
    if (pct != null) return (pct / 100).clamp(0.0, 1.0);
    return 0.7;
  }

  Map<String, double>? get _optionPercentages =>
      _attemptSummaries[_currentQuestion.id]?.optionPercentages ??
      _currentQuestion.optionPercentages;

  /// Gerçek veri yokken debug APK'da şık yüzdelerini önizlemek için.
  Map<String, double> get _visibleOptionPercentages {
    final live = _optionPercentages;
    if (live != null && live.isNotEmpty) return live;
    if (!kDebugMode) return const {};

    final keys = _currentQuestion.siklar.keys.toList();
    final correct = _currentQuestion.dogruCevap;
    final preview = <String, double>{};
    final distractors = keys.where((key) => key != correct).toList();
    for (var index = 0; index < distractors.length; index++) {
      preview[distractors[index]] = switch (index) {
        0 => 8.0,
        1 => 5.0,
        2 => 3.0,
        _ => 2.0,
      };
    }
    final used = preview.values.fold<double>(0, (sum, value) => sum + value);
    preview[correct] = double.parse((100 - used).toStringAsFixed(1));
    return preview;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  QuizResult _buildResult({
    required bool completed,
    bool submitDailyMiniRanking = false,
  }) {
    var correct = 0;
    var wrong = 0;
    var blank = 0;
    final wrongIds = <String>[];
    final correctIds = <String>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      switch (gradeAnswer(q, _answers[i])) {
        case AnswerState.correct:
          correct++;
          correctIds.add(q.id);
        case AnswerState.wrong:
          wrong++;
          wrongIds.add(q.id);
        case AnswerState.blank:
          blank++;
      }
    }
    return QuizResult(
      correct: correct,
      wrong: wrong,
      blank: blank,
      total: widget.questions.length,
      duration: DateTime.now().difference(_startedAt),
      completed: completed,
      submitDailyMiniRanking: submitDailyMiniRanking,
      questionIds: widget.questions.map((q) => q.id).toList(),
      wrongQuestionIds: wrongIds,
      correctQuestionIds: correctIds,
      selectedAnswers: List<String?>.from(_answers),
    );
  }

  ({Color fill, Color border, Color text}) _questionChipColors({
    required bool answered,
    required bool answeredCorrectly,
    required bool previouslySolved,
    required bool active,
  }) {
    if (answered) {
      final answerColor =
          answeredCorrectly ? _correctGreen : _answeredWrongBurgundy;
      return (
        fill: answerColor.withValues(alpha: active ? 0.42 : 0.28),
        border: answerColor,
        text: Colors.white,
      );
    }
    if (previouslySolved) {
      return (
        fill: _previousBlue.withValues(alpha: active ? 0.32 : 0.2),
        border: _previousBlue,
        text: Colors.white,
      );
    }
    return (
      fill: active ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
      border: Colors.white.withValues(alpha: active ? 1 : 0.82),
      text: Colors.white,
    );
  }

  Future<bool> _onWillPop() async {
    _answers[_currentIndex] = _selectedAnswer;
    if (widget.fromWrongNotebook) {
      return true;
    }
    if (widget.tgExamMode && !widget.tgExamSolutionReview) {
      await _persistProgress();
      if (!mounted) return false;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: const Text(
            'Denemeden çık',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'İlerlemen kaydedilir. Kişisel sayacın duraklar; sayaç bitene kadar '
            'kaldığın yerden devam edebilirsin.',
            style: TextStyle(
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppTheme.champagne),
              child: const Text('Devam et'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.champagne,
                foregroundColor: AppTheme.ink,
              ),
              child: const Text('Kaydet ve çık'),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    await _persistProgress();
    if (!mounted) return false;

    if (widget.dailyMiniRankingMode &&
        !DailyMiniExamService.instance.rankingLocked) {
      final answeredCount =
          _answers.where((a) => a != null && a.isNotEmpty).length;
      final result = await showDialog<_DailyMiniExitChoice>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: const Text(
            'Mini denemeden çık',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            answeredCount == 0
                ? 'Henüz cevap vermediniz. Çıkarsanız ilerlemeniz kaydedilir; '
                    'sıralamaya girmek için en az bir soru işaretlemelisiniz.'
                : 'Şu ana kadar verdiğiniz $answeredCount cevap sıralamaya '
                    'girer. Sonra devam etseniz bile sıralamanız güncellenmez.\n\n'
                    'İnternet yoksa çıkabilirsiniz; bağlantı gelince kaldığınız '
                    'yerden sürdürüp sıralamayı o zaman gönderebilirsiniz.',
            style: TextStyle(
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _DailyMiniExitChoice.stay),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.champagne,
              ),
              child: const Text('Devam et'),
            ),
            if (answeredCount > 0)
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _DailyMiniExitChoice.submitRanking,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.champagne,
                  foregroundColor: AppTheme.ink,
                ),
                child: const Text('Sıralamaya gönder'),
              )
            else
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _DailyMiniExitChoice.saveOnly,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.champagne,
                  foregroundColor: AppTheme.ink,
                ),
                child: const Text('Kaydet ve çık'),
              ),
          ],
        ),
      );
      if (result == null || result == _DailyMiniExitChoice.stay) {
        return false;
      }
      if (result == _DailyMiniExitChoice.submitRanking) {
        _popWithResult(
          completed: false,
          submitDailyMiniRanking: true,
        );
        return false;
      }
      _popWithResult(completed: false);
      return false;
    }

    if (widget.dailyMiniRankingMode &&
        DailyMiniExamService.instance.rankingLocked) {
      final svc = DailyMiniExamService.instance;
      if (svc.formallyFinished || !svc.canResumeQuiz) {
        _popWithResult(completed: false);
        return false;
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: const Text(
            'Mini denemeden çık',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Sıralamanız kayıtlı. Kaldığınız yerden çözmeye devam '
            'edebilirsiniz; sıralama değişmez.',
            style: TextStyle(
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.champagne,
              ),
              child: const Text('Devam et'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.champagne,
                foregroundColor: AppTheme.ink,
              ),
              child: const Text('Kaydet ve çık'),
            ),
          ],
        ),
      );
      return result ?? false;
    }

    var wrongSoFar = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      if (gradeAnswer(widget.questions[i], _answers[i]) == AnswerState.wrong) {
        wrongSoFar++;
      }
    }

    final wrongHint = wrongSoFar > 0
        ? '\n\nŞu ana kadar $wrongSoFar yanlış. Testi bitirmeden çıkarsanız '
            'Yanlış Defterine eklenmez; kaldığınız soruya sonra dönebilirsiniz.'
        : '\n\nİlerlemeniz kaydedilir. İstediğiniz zaman kaldığınız sorudan '
            'devam edebilirsiniz.';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.inkSoft,
        title: const Text(
          'Testten çık',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Çıkmak istediğinize emin misiniz?'
          '$wrongHint',
          style: TextStyle(
            height: 1.45,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.champagne,
            ),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: AppTheme.ink,
            ),
            child: const Text('Kaydet ve çık'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static const _drawingKeySep = '::';

  String _drawingStorageKey(String questionId, {required bool solution}) =>
      '$questionId$_drawingKeySep${solution ? 'solution' : 'question'}';

  String get _activeDrawingKey => _drawingStorageKey(
        _currentQuestion.id,
        solution: _showingSolution,
      );

  Future<void> _loadPersistedDrawings(String questionId) async {
    if (!widget.fromWrongNotebook) return;
    await WrongNotebookDrawingService.instance.initialize();
    if (!mounted) return;
    for (final solution in [false, true]) {
      final strokes = WrongNotebookDrawingService.instance.strokesFor(
        questionId,
        solution: solution,
      );
      if (strokes.isEmpty) continue;
      _drawings[_drawingStorageKey(questionId, solution: solution)] =
          List<QuizStroke>.from(strokes);
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistDrawingSurface({
    required String questionId,
    required bool solution,
  }) async {
    if (!widget.fromWrongNotebook) return;
    final key = _drawingStorageKey(questionId, solution: solution);
    await WrongNotebookDrawingService.instance.saveStrokes(
      questionId,
      solution: solution,
      strokes: _drawings[key] ?? const [],
    );
  }

  Future<void> _persistCurrentDrawings() async {
    if (!widget.fromWrongNotebook || widget.questions.isEmpty) return;
    final questionId = _currentQuestion.id;
    await Future.wait([
      _persistDrawingSurface(questionId: questionId, solution: false),
      _persistDrawingSurface(questionId: questionId, solution: true),
    ]);
  }

  void _exitWrongNotebook() {
    if (_isFinishing || !mounted) return;
    _isFinishing = true;
    _drawingEnabled = false;
    _ticker?.cancel();
    unawaited(_persistCurrentDrawings());
    AdManager.instance.endTestSession();
    Navigator.of(context).pop();
  }

  void _popWithResult({
    required bool completed,
    bool submitDailyMiniRanking = false,
  }) {
    if (widget.questions.isNotEmpty) {
      _answers[_currentIndex] = _selectedAnswer;
    }
    _isFinishing = true;
    _drawingEnabled = false;
    if (completed) _drawings.clear();
    if (completed) {
      unawaited(LastStudySessionService.instance.clearQuizProgress());
    } else {
      unawaited(_persistProgress());
    }
    Navigator.of(context).pop(
      _buildResult(
        completed: completed,
        submitDailyMiniRanking: submitDailyMiniRanking,
      ),
    );
  }

  /// Stem → options share one [SingleChildScrollView]; keep offset across
  /// question changes so "Sonraki" would otherwise open mid-scroll on options.
  void _resetScrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  /// Soru gövdesi (senaryo + kök + çözüm/şıklar + puan) — zoom ve çizim ortak.
  Widget _buildQuestionBody({required EdgeInsets padding}) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentQuestion.hasScenarioPassage) ...[
            _ScenarioPassageCard(question: _currentQuestion),
            const SizedBox(height: 16),
          ],
          QuestionStemPanel(
            child: QuestionStemContent(
              stem: _currentQuestion.soruMetni,
              imageUrl: _currentQuestion.imageUrl,
              stemImagePosition: _currentQuestion.stemImagePosition,
              sekilKodu: _currentQuestion.sekilKodu,
            ),
          ),
          const SizedBox(height: 20),
          if (_showingSolution)
            ListenableBuilder(
              listenable: AdManager.instance,
              builder: (context, _) {
                return _SolutionPanel(
                  question: _currentQuestion,
                  selectedAnswer: _selectedAnswer,
                  showFullSolution: _isSolutionFullyUnlocked,
                  unlocking: _solutionUnlocking,
                  dailyRemaining: AdManager.instance.dailyDetailedSolutionsRemaining,
                  proGateRequired: AdManager.instance
                          .isDailyDetailedSolutionLimitReached &&
                      !_isSolutionFullyUnlocked &&
                      !PremiumService.instance.isPremium &&
                      !widget.adFreeExperience &&
                      !widget.tgExamSolutionReview,
                  onUnlockFull: _unlockFullSolution,
                );
              },
            )
          else ...[
            ..._matchingOptionHeaders(_currentQuestion),
            ..._currentQuestion.siklar.entries.map(
              (entry) {
                final selected = _selectedAnswer == entry.key;
                final revealed = widget.tgExamSolutionReview ||
                    widget.fromWrongNotebook ||
                    (!widget.tgExamMode && _selectedAnswer != null);
                final isCorrectKey =
                    entry.key == _currentQuestion.dogruCevap;
                _OptionTone? tone;
                if (revealed) {
                  if (widget.tgExamMode && !widget.tgExamSolutionReview) {
                    tone = null;
                  } else if (isCorrectKey) {
                    tone = _OptionTone.correct;
                  } else if (selected) {
                    tone = _OptionTone.wrong;
                  }
                }
                return _OptionTile(
                  label: entry.key,
                  text: entry.value,
                  imageUrl: _currentQuestion.optionImageUrlFor(entry.key),
                  forceColumns: OptionColumnLayout.forcedColumns(
                    _currentQuestion.optionTable,
                  ),
                  isSelected: selected,
                  tone: tone,
                  percentage: revealed && !widget.tgExamMode
                      ? _visibleOptionPercentages[entry.key]
                      : null,
                  onTap: widget.tgExamSolutionReview || widget.fromWrongNotebook
                      ? () {}
                      : () => _selectAnswer(entry.key),
                );
              },
            ),
          ],
          if (_selectedAnswer != null &&
              AuthService.instance.isSignedIn &&
              QuestionRatingService.canRate(
                _currentQuestion.id,
              )) ...[
            const SizedBox(height: 16),
            QuestionRatingBar(
              selectedStars: _ratingSummary?.userRating,
              averageRating: _ratingSummary?.averageRating,
              ratingCount: _ratingSummary?.ratingCount ?? 0,
              loading: _ratingLoading,
              saving: _ratingSaving,
              onRate: _rateQuestion,
            ),
          ],
        ],
      ),
    );
  }

  void _goTo(int index) {
    if (_isFinishing || widget.questions.isEmpty) return;
    if (index < 0 || index >= widget.questions.length) return;
    if (index == _currentIndex) return;
    _answers[_currentIndex] = _selectedAnswer;
    if (widget.fromWrongNotebook) {
      unawaited(_persistCurrentDrawings());
    }
    setState(() {
      _currentIndex = index;
      _selectedAnswer = _answers[index];
      _showingSolution = widget.tgExamSolutionReview;
      _solutionUnlocking = false;
      _drawingEnabled = false;
      _contentZoom.value = Matrix4.identity();
      _resetRatingState();
      _resetErrorReportState();
      _syncTimerForCurrentQuestion();
      _refreshWrongNotebookHint();
    });
    _resetScrollToTop();
    unawaited(_persistProgress());
    if (_selectedAnswer != null) unawaited(_loadRating());
    unawaited(_loadErrorReportState());
    unawaited(_recordCurrentView());
    if (widget.fromWrongNotebook) {
      unawaited(_loadPersistedDrawings(widget.questions[index].id));
    }
  }

  Future<void> _recordCurrentView() async {
    if (!mounted || widget.questions.isEmpty) return;
    final question = _currentQuestion;
    final id = question.id;
    if (!_viewedIds.add(id)) return;
    final result = await QuestionViewService.instance.recordView(id);
    if (!mounted || result == null) return;
    final previous = _viewCounts[id] ?? question.viewCount;
    setState(() {
      if (result.viewCount > previous) {
        _viewCounts[id] = result.viewCount;
      }
      final rate = result.correctRate;
      if (rate != null) {
        _liveCorrectRates[id] = rate;
      }
    });
  }

  String _viewLabelForCurrent() {
    if (widget.questions.isEmpty) return '0 kişi gördü';
    final q = _currentQuestion;
    final local = _viewCounts[q.id] ?? 0;
    final n = local > q.viewCount ? local : q.viewCount;
    return '$n kişi gördü';
  }

  Future<void> _toggleFavorite() async {
    await FavoritesService.instance.toggle(_currentQuestion.id);
    if (mounted) setState(() {});
  }

  void _resetRatingState() {
    _ratingSummary = null;
    _ratingQuestionId = null;
    _ratingLoading = false;
    _ratingSaving = false;
  }

  void _resetErrorReportState() {
    _errorReported = false;
    _errorReportLoading = false;
    // Günlük limit oturum boyunca korunur; soru değişince sıfırlanmaz.
  }

  String _difficultyLabel() {
    // Yayın sürümünde de süre altında Seviye rozeti görünsün.
    // difficultyVisible: otomatik sınıflandırma eşiği (API); etiket her zaman
    // sorunun güncel difficulty alanından okunur.
    if (kDebugMode && !_currentQuestion.difficultyVisible) {
      // Debug APK'da üç rozet görünümünü incelemek için.
      return switch (_currentIndex % 3) {
        0 => 'Kolay',
        1 => 'Orta',
        _ => 'Zor',
      };
    }
    return switch (_currentQuestion.difficulty) {
      'easy' => 'Kolay',
      'hard' => 'Zor',
      _ => 'Orta',
    };
  }

  Future<void> _loadErrorReportState() async {
    if (!mounted || widget.questions.isEmpty) return;
    final questionId = _currentQuestion.id;
    if (!QuestionErrorReportService.canReport(questionId) ||
        !AuthService.instance.hasPermanentAccount) {
      if (mounted) {
        setState(() {
          _errorReported = false;
          _errorReportLoading = false;
        });
      }
      return;
    }
    final cached = QuestionErrorReportService.instance.cached(questionId);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _errorReported = cached.reported;
          _errorDailyLimitReached = cached.dailyLimitReached ||
              QuestionErrorReportService.instance.dailyLimitReached;
          _errorReportLoading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _errorReportLoading = true);
    try {
      final state = await QuestionErrorReportService.instance.load(questionId);
      if (!mounted || _currentQuestion.id != questionId) return;
      setState(() {
        _errorReported = state.reported;
        _errorDailyLimitReached = state.dailyLimitReached;
        _errorReportLoading = false;
      });
    } catch (_) {
      if (!mounted || _currentQuestion.id != questionId) return;
      setState(() => _errorReportLoading = false);
    }
  }

  Future<void> _openErrorReport() async {
    final questionId = _currentQuestion.id;
    if (!QuestionErrorReportService.canReport(questionId)) return;
    if (!AuthService.instance.hasPermanentAccount) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: const Text(
            'Hata bildirimi',
            style: TextStyle(color: Colors.white, fontFamily: 'serif'),
          ),
          content: const Text(
            QuestionErrorReportService.guestWarning,
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tamam',
                  style: TextStyle(color: AppTheme.neonEdge)),
            ),
          ],
        ),
      );
      return;
    }
    if (!QuestionErrorReportService.instance.meetsLocalTestRequirement()) {
      if (!mounted) return;
      final completed = ContentBankService.instance.completedTopicTestCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            QuestionErrorReportService.testsRequiredWarning(
              completed: completed,
              required: QuestionErrorReportService.instance.minTestsRequiredNow,
            ),
          ),
        ),
      );
      return;
    }
    try {
      final state = await QuestionErrorReportService.instance.load(questionId);
      if (!mounted) return;
      if (!state.testsRequirementMet) {
        final local = ContentBankService.instance.completedTopicTestCount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              QuestionErrorReportService.testsRequiredWarning(
                completed: state.testsCompleted,
                required: state.minTestsRequired,
                localCompleted: local,
              ),
            ),
          ),
        );
        return;
      }
      if (state.reported || !state.canReport) {
        setState(() {
          _errorReported = state.reported;
          _errorDailyLimitReached = state.dailyLimitReached;
        });
        if (state.reported) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu soruyu zaten bildirdiniz.')),
          );
        } else if (state.dailyLimitReached) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Günde yalnızca 1 hata bildirimi yapabilirsiniz.'),
            ),
          );
        }
        return;
      }
    } on QuestionErrorReportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hata bildirimi durumu alınamadı. İnternet bağlantınızı kontrol edin.',
          ),
        ),
      );
      return;
    }
    if (_errorReported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu soruyu zaten bildirdiniz.')),
      );
      return;
    }
    if (_errorDailyLimitReached ||
        QuestionErrorReportService.instance.dailyLimitReached) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Günde yalnızca 1 hata bildirimi yapabilirsiniz.'),
        ),
      );
      return;
    }
    final submitted = await showQuestionErrorReportSheet(
      context: context,
      onSubmit: (category, note) async {
        await QuestionErrorReportService.instance.submit(
          questionId: questionId,
          category: category,
          note: note,
        );
      },
    );
    if (!mounted || submitted != true) return;
    setState(() {
      _errorReported = true;
      _errorDailyLimitReached = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teşekkürler — bildiriminiz incelenecek.'),
      ),
    );
  }

  Future<void> _loadRating() async {
    if (!mounted || widget.questions.isEmpty) return;
    if (!AuthService.instance.isSignedIn ||
        !QuestionRatingService.canRate(_currentQuestion.id)) {
      return;
    }
    final questionId = _currentQuestion.id;
    if (_ratingQuestionId == questionId &&
        (_ratingSummary != null || _ratingLoading)) {
      return;
    }
    final cached = QuestionRatingService.instance.cached(questionId);
    if (!mounted) return;
    setState(() {
      _ratingQuestionId = questionId;
      _ratingSummary = cached;
      _ratingLoading = cached == null;
    });
    try {
      final summary = await QuestionRatingService.instance.load(questionId);
      if (!mounted || _currentQuestion.id != questionId) return;
      setState(() {
        _ratingSummary = summary;
        _ratingLoading = false;
      });
    } catch (_) {
      if (!mounted || _currentQuestion.id != questionId) return;
      setState(() => _ratingLoading = false);
    }
  }

  Future<void> _rateQuestion(int stars) async {
    if (_ratingSaving) return;
    final questionId = _currentQuestion.id;
    setState(() => _ratingSaving = true);
    try {
      final summary = await QuestionRatingService.instance.rate(
        questionId,
        stars,
      );
      if (!mounted || _currentQuestion.id != questionId) return;
      setState(() => _ratingSummary = summary);
    } catch (error) {
      if (!mounted || _currentQuestion.id != questionId) return;
      final message = error is QuestionRatingException
          ? error.message
          : 'Puan kaydedilemedi. Bağlantınızı kontrol edip tekrar deneyin.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted && _currentQuestion.id == questionId) {
        setState(() => _ratingSaving = false);
      }
    }
  }

  Future<void> _requestSolution() async {
    if (widget.adFreeExperience || widget.tgExamSolutionReview) {
      AdManager.instance.grantSessionSolutionUnlock(_currentQuestion.id);
    } else {
      await AdManager.instance.ensureFreeSolutionUnlock(_currentQuestion.id);
    }
    if (!mounted) return;
    setState(() => _showingSolution = true);
  }

  bool get _isSolutionFullyUnlocked {
    if (widget.tgExamSolutionReview) return true;
    return PremiumService.instance.isPremium ||
        AdManager.instance.isSolutionUnlocked(_currentQuestion.id);
  }

  Future<void> _unlockFullSolution() async {
    if (_isSolutionFullyUnlocked) {
      setState(() => _showingSolution = true);
      return;
    }

    if (widget.adFreeExperience || widget.tgExamSolutionReview) {
      AdManager.instance.grantSessionSolutionUnlock(_currentQuestion.id);
      setState(() => _showingSolution = true);
      return;
    }

    if (PremiumService.instance.isPremium) {
      AdManager.instance.grantSessionSolutionUnlock(_currentQuestion.id);
      setState(() => _showingSolution = true);
      return;
    }

    if (await AdManager.instance.ensureFreeSolutionUnlock(_currentQuestion.id)) {
      if (!mounted) return;
      setState(() => _showingSolution = true);
      return;
    }

    if (AdManager.instance.isDailyDetailedSolutionLimitReached) {
      if (!mounted) return;
      await ProUpsellSheet.show(
        context,
        emoji: '📖',
        title: 'DETAYLI ÇÖZÜM',
        subtitle:
            'Günde ${AdConstants.freeDetailedSolutionsPerDay} detaylı çözüm '
            'hakkın doldu. Sınırsız adım adım çözüm için Pro Üye ol',
        cta: 'Pro Üye ol',
      );
      if (!mounted) return;
      if (PremiumService.instance.isPremium) {
        AdManager.instance.grantSessionSolutionUnlock(_currentQuestion.id);
        setState(() => _showingSolution = true);
      }
      return;
    }

    setState(() => _solutionUnlocking = true);
    final success = await AdManager.instance.requestSolutionUnlock(
      _currentQuestion.id,
    );
    if (!mounted) return;
    setState(() => _solutionUnlocking = false);

    if (success) {
      setState(() => _showingSolution = true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Reklam yüklenemedi veya izlenmedi. Önizleme açık kaldı.',
        ),
      ),
    );
  }

  void _nextQuestion() {
    if (_isFinishing) return;
    _answers[_currentIndex] = _selectedAnswer;
    if (_currentIndex < widget.questions.length - 1) {
      if (widget.fromWrongNotebook) {
        unawaited(_persistCurrentDrawings());
      }
      setState(() {
        _currentIndex++;
        _selectedAnswer = _answers[_currentIndex];
        _showingSolution = widget.tgExamSolutionReview;
        _solutionUnlocking = false;
        _drawingEnabled = false;
        _contentZoom.value = Matrix4.identity();
        _resetRatingState();
        _resetErrorReportState();
        _syncTimerForCurrentQuestion();
        _refreshWrongNotebookHint();
      });
      _resetScrollToTop();
      unawaited(_persistProgress());
      if (_selectedAnswer != null) unawaited(_loadRating());
      unawaited(_loadErrorReportState());
      unawaited(_recordCurrentView());
      if (widget.fromWrongNotebook) {
        unawaited(
          _loadPersistedDrawings(widget.questions[_currentIndex].id),
        );
      }
    } else {
      if (widget.fromWrongNotebook) {
        _exitWrongNotebook();
        return;
      }
      unawaited(_requestFinish());
    }
  }

  Future<void> _requestFinish() async {
    if (_isFinishing || !mounted) return;
    _answers[_currentIndex] = _selectedAnswer;
    var blankCount = 0;
    var firstBlank = -1;
    for (var i = 0; i < widget.questions.length; i++) {
      if (gradeAnswer(widget.questions[i], _answers[i]) == AnswerState.blank) {
        blankCount++;
        firstBlank = firstBlank < 0 ? i : firstBlank;
      }
    }
    final finishTitle =
        widget.tgExamMode ? 'Sınavı Tamamla' : 'Boş sorular var';
    if (blankCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: Text(
            finishTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            widget.tgExamMode
                ? (blankCount == 1
                    ? '1 soruyu boş bıraktınız. Sınavı göndermek istiyor musunuz?'
                    : '$blankCount soruyu boş bıraktınız. Sınavı göndermek istiyor musunuz?')
                : (blankCount == 1
                    ? '1 soruyu boş bıraktınız. Testi yine de bitirmek istiyor musunuz?'
                    : '$blankCount soruyu boş bıraktınız. Testi yine de bitirmek istiyor musunuz?'),
            style: TextStyle(
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.champagne,
              ),
              child: const Text('Geri dön'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.champagne,
                foregroundColor: AppTheme.ink,
              ),
              child: Text(widget.tgExamMode ? 'Gönder' : 'Yine de bitir'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        if (confirmed == false && firstBlank >= 0 && mounted) {
          _goTo(firstBlank);
        }
        return;
      }
    } else if (widget.tgExamMode) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: const Text(
            'Sınavı Tamamla',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Cevaplarınız gönderilecek. Onaylıyor musunuz?',
            style: TextStyle(
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppTheme.champagne),
              child: const Text('Geri dön'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.champagne,
                foregroundColor: AppTheme.ink,
              ),
              child: const Text('Gönder'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _finishTest();
  }

  void _previousQuestion() {
    if (_isFinishing || _currentIndex <= 0) return;
    _answers[_currentIndex] = _selectedAnswer;
    if (widget.fromWrongNotebook) {
      unawaited(_persistCurrentDrawings());
    }
    setState(() {
      _currentIndex--;
      _selectedAnswer = _answers[_currentIndex];
      _showingSolution = widget.tgExamSolutionReview;
      _solutionUnlocking = false;
      _drawingEnabled = false;
      _resetRatingState();
      _resetErrorReportState();
      _syncTimerForCurrentQuestion();
      _refreshWrongNotebookHint();
    });
    _resetScrollToTop();
    unawaited(_persistProgress());
    if (_selectedAnswer != null) unawaited(_loadRating());
    unawaited(_loadErrorReportState());
    unawaited(_recordCurrentView());
    if (widget.fromWrongNotebook) {
      unawaited(
        _loadPersistedDrawings(widget.questions[_currentIndex].id),
      );
    }
  }

  Future<bool> _showResultDialog(QuizResult result) {
    final shareKey = GlobalKey();
    var sharing = false;
    final showWrongReview = _canReviewSessionWrongs && result.wrong > 0;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final gamification = GamificationService.instance;
            final gainedXp = gamification.xpForCompletedTest(
              correct: result.correct,
              wrong: result.wrong,
              duration: result.duration,
            );
            final streak = gamification.previewStreakAfterTest();

            return AlertDialog(
              backgroundColor: AppTheme.inkSoft,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _resultHeading,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppTheme.champagneLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _emotionalFeedback(result),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultRewardChip(
                            icon: Icons.bolt_rounded,
                            label: '+$gainedXp XP',
                            color: AppTheme.neonEdge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ResultRewardChip(
                            icon: Icons.local_fire_department_rounded,
                            label: '$streak gün seri',
                            color: const Color(0xFFFB923C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: RepaintBoundary(
                        key: shareKey,
                        child: ShareableResultCard(
                          testTitle: widget.title,
                          result: result,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: sharing
                      ? null
                      : () async {
                          setDialogState(() => sharing = true);
                          await ResultCardShare.share(
                            boundaryKey: shareKey,
                            testTitle: widget.title,
                            result: result,
                          );
                          if (context.mounted) {
                            setDialogState(() => sharing = false);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.neonEdge,
                    side: BorderSide(
                      color: AppTheme.neonEdge.withValues(alpha: 0.65),
                    ),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: sharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_outlined, size: 18),
                  label: Text(sharing ? 'Hazırlanıyor…' : 'Sonucu paylaş'),
                ),
                const SizedBox(height: 8),
                if (showWrongReview) ...[
                  _ResultWrongReviewButton(wrongCount: result.wrong),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.champagne,
                    foregroundColor: AppTheme.ink,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('Tamam'),
                ),
              ],
            );
          },
        );
      },
    ).then((value) => value ?? false);
  }

  bool get _canReviewSessionWrongs {
    if (widget.tgExamMode ||
        widget.dailyMiniRankingMode ||
        widget.fromWrongNotebook ||
        widget.suppressWrongNotebookHint) {
      return false;
    }
    // Konu testi, deneme paketi (Matematik vb.), devam kartı…
    if (widget.resumeMeta != null) return true;
    if (widget.statisticsTestId != null) return true;
    if (widget.adFreeExperience && !widget.skipResultDialog) return true;
    return false;
  }

  WrongNotebookSessionFilter _buildWrongSessionFilter(QuizResult result) {
    final meta = widget.resumeMeta;
    if (meta != null) {
      return WrongNotebookSessionFilter.fromTopicQuiz(
        meta: meta,
        fallbackTitle: widget.title,
        wrongQuestionIds: result.wrongQuestionIds,
        allQuestions: widget.questions,
        testId: widget.statisticsTestId,
      );
    }
    final title = widget.title.trim().isEmpty ? 'Test' : widget.title.trim();
    final count = result.wrong;
    final byId = {for (final q in widget.questions) q.id: q};
    final prefetched = result.wrongQuestionIds
        .map((id) => byId[id])
        .whereType<QuestionModel>()
        .toList();
    return WrongNotebookSessionFilter(
      sessionTitle: '$title Yanlışları ($count Soru)',
      testId: widget.statisticsTestId,
      questionIds: List<String>.from(result.wrongQuestionIds),
      prefetchedQuestions: prefetched,
    );
  }

  Future<void> _finishTest() async {
    if (_isFinishing || !mounted) return;
    setState(() {
      _isFinishing = true;
      _drawingEnabled = false;
    });
    _ticker?.cancel();
    if (widget.questions.isNotEmpty) {
      _answers[_currentIndex] = _selectedAnswer;
    }
    _drawings.clear();
    final result = _buildResult(completed: true);

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // Bitiş sesi reklamdan ÖNCE — interstitial ses odağını alınca efekt kayboluyordu.
    final playFinishSound =
        !widget.skipResultDialog && !widget.tgExamSolutionReview;
    if (playFinishSound) {
      await AnswerFeedbackService.instance.playTestComplete();
      if (!mounted) return;
    }

    if (!widget.tgExamMode && !widget.adFreeExperience) {
      await AdManager.instance.showTestCompletionInterstitial();
    }
    if (!mounted) return;
    AdManager.instance.endTestSession();
    await LastStudySessionService.instance.clearQuizProgress();
    if (!mounted) return;

    var reviewWrongs = false;
    if (!widget.skipResultDialog) {
      reviewWrongs = await _showResultDialog(result);
      if (!mounted) return;
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    final sessionFilter =
        reviewWrongs ? _buildWrongSessionFilter(result) : null;

    if (sessionFilter != null) {
      final wrongModels = widget.questions
          .where((q) => result.wrongQuestionIds.contains(q.id))
          .toList();
      if (wrongModels.isNotEmpty) {
        ContentBankService.instance.mergeSessionQuestions(wrongModels);
      }
      await ContentBankService.instance.updateAnswerOutcomes(
        wrongQuestionIds: result.wrongQuestionIds,
        correctQuestionIds: result.correctQuestionIds,
        questionIds: result.questionIds,
        selectedAnswers: result.selectedAnswers,
      );
    }

    if (!mounted) return;
    navigator.pop(result);

    if (sessionFilter != null && navigator.mounted) {
      await openWrongNotebookSession(navigator, sessionFilter);
    }
  }

  Widget _buildBottomActions() {
    final isLast = _currentIndex >= widget.questions.length - 1;
    final canGoBack = _currentIndex > 0 && !_isFinishing;
    final canAdvance = !_isFinishing;

    ButtonStyle navOutlineStyle({required bool enabled}) =>
        OutlinedButton.styleFrom(
          foregroundColor: enabled
              ? _quizAccentLight
              : Colors.white.withValues(alpha: 0.28),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.28),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          side: BorderSide(
            color: _quizAccent.withValues(alpha: enabled ? 0.42 : 0.14),
          ),
          backgroundColor: enabled
              ? _quizAccent.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.02),
          textStyle: const TextStyle(
            fontFamily: 'serif',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        );

    final canToggleSolution = !widget.tgExamMode &&
        (_showingSolution || (_selectedAnswer != null && !_isFinishing));
    ButtonStyle solutionStyle({required bool enabled}) =>
        OutlinedButton.styleFrom(
          foregroundColor: enabled
              ? AppTheme.champagneLight
              : AppTheme.champagneLight.withValues(alpha: 0.35),
          disabledForegroundColor:
              AppTheme.champagneLight.withValues(alpha: 0.35),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          side: BorderSide(
            color: AppTheme.champagne.withValues(alpha: enabled ? 0.62 : 0.18),
          ),
          backgroundColor: enabled
              ? AppTheme.champagne.withValues(alpha: 0.16)
              : Colors.transparent,
          textStyle: const TextStyle(
            fontFamily: 'serif',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        );

    return SafeArea(
      top: false,
      child: Material(
        color: _quizInkSoft,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: _quizAccent.withValues(alpha: 0.22),
              ),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _quizInkSoft,
                _quizInk,
              ],
            ),
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canGoBack ? _previousQuestion : null,
                      style: navOutlineStyle(enabled: canGoBack),
                      child: const Text(
                        'Önceki',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (!widget.tgExamMode) const SizedBox(width: 6),
                  if (!widget.tgExamMode)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: !canToggleSolution
                            ? null
                            : _showingSolution
                                ? () => setState(() {
                                      _showingSolution = false;
                                      _drawingEnabled = false;
                                    })
                                : _requestSolution,
                        style: solutionStyle(enabled: canToggleSolution),
                        child: Text(
                          _showingSolution ? 'Çözümü Gizle' : 'Çözümü Gör',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (!widget.tgExamMode) const SizedBox(width: 6),
                  if (widget.tgExamMode) const SizedBox(width: 6),
                  Expanded(
                    child: isLast
                        ? FilledButton(
                            onPressed: canAdvance
                                ? (widget.fromWrongNotebook
                                    ? _exitWrongNotebook
                                    : _nextQuestion)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: _quizAccent,
                              foregroundColor: _quizInk,
                              disabledBackgroundColor:
                                  _quizAccent.withValues(alpha: 0.35),
                              disabledForegroundColor:
                                  _quizInk.withValues(alpha: 0.45),
                              minimumSize: const Size(0, 48),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'serif',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            child: Text(
                              widget.fromWrongNotebook
                                  ? 'Çıkış'
                                  : (widget.tgExamMode ? 'Tamamla' : 'Bitir'),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : OutlinedButton(
                            onPressed: canAdvance ? _nextQuestion : null,
                            style: navOutlineStyle(enabled: canAdvance),
                            child: const Text(
                              'Sonraki',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Test adı sola; Soru X/Y ekran ortasında (ÖSYM rozeti ile aynı eksen).
  /// Boş başlıkta (ör. tüm yanlışları çöz) yalnızca Soru X/Y gösterilir.
  Widget _buildTestAppBarTitle() {
    const leadingW = 56.0;
    final canReport =
        QuestionErrorReportService.canReport(_currentQuestion.id);
    final actionCount = 1 + (canReport ? 1 : 0) + 1;
    final actionsW = actionCount * 40.0 + 2;
    final titleW =
        MediaQuery.sizeOf(context).width - leadingW - actionsW;
    final testTitle = widget.title.trim();

    return SizedBox(
      width: titleW.clamp(120, 800),
      height: kToolbarHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (testTitle.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(8, 0),
                child: SizedBox(
                  width: titleW.clamp(120.0, 800.0),
                  child: _tgLiveExam
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: EmbossedAppBarTitle(
                            testTitle,
                            alignLeft: true,
                            fontSize: 14,
                          ),
                        )
                      : EmbossedAppBarTitle(
                          testTitle,
                          alignLeft: true,
                        ),
                ),
              ),
            ),
          if (!widget.hideQuestionCounter && !_tgLiveExam)
            Transform.translate(
              offset: Offset((actionsW - leadingW) / 2, 0),
              child: Text(
                'Soru ${_currentIndex + 1}/${widget.questions.length}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.15,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.ink,
        appBar: AppBar(
          backgroundColor: AppTheme.inkSoft,
          foregroundColor: Colors.white,
          leading: AppBackButton.onDark(accent: AppTheme.champagne),
        ),
        body: const Center(
          child: Text(
            'Bu testte soru yok.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final isFav = FavoritesService.instance.isFavorite(_currentQuestion.id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (widget.fromWrongNotebook) {
          _exitWrongNotebook();
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          _popWithResult(completed: false);
        }
      },
      child: Scaffold(
        backgroundColor: _quizInk,
        appBar: AppBar(
          backgroundColor: _quizInkSoft,
          foregroundColor: Colors.white,
          centerTitle: false,
          titleSpacing: 0,
          leadingWidth: 56,
          leading: AppBackButton.onDark(
            accent: _quizAccent,
            onPressed: () async {
            if (widget.fromWrongNotebook) {
              _exitWrongNotebook();
              return;
            }
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) {
              _popWithResult(completed: false);
            }
          }),
          title: widget.dailyMiniRankingMode
              ? ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF7EED8),
                      AppTheme.champagneLight,
                      AppTheme.neonGold,
                      AppTheme.champagne,
                      Color(0xFFB8944A),
                    ],
                    stops: [0.0, 0.22, 0.48, 0.72, 1.0],
                  ).createShader(bounds),
                  child: const Text(
                    DailyMiniExamConstants.title,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: Colors.white,
                      height: 1.05,
                    ),
                  ),
                )
              : widget.fromWrongNotebook
                  ? Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.champagne,
                        height: 1.15,
                      ),
                    )
                  : _buildTestAppBarTitle(),
          actionsPadding: const EdgeInsets.only(right: 2),
          actions: [
            SizedBox(
              width: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: _drawingEnabled
                    ? 'Çizimi kapat (yakınlaştırma açılır)'
                    : 'Çizim modu (yakınlaştırma kilitlenir)',
                onPressed: _isFinishing
                    ? null
                    : () => setState(() {
                          final next = !_drawingEnabled;
                          if (next) {
                            // Çizim: zoom sıfır + kilitle.
                            _contentZoom.value = Matrix4.identity();
                          }
                          _drawingEnabled = next;
                        }),
                icon: Icon(
                  _drawingEnabled
                      ? Icons.edit_off_outlined
                      : Icons.edit_rounded,
                  color: _drawingEnabled ? AppTheme.champagne : Colors.white,
                ),
              ),
            ),
            if (QuestionErrorReportService.canReport(_currentQuestion.id))
              SizedBox(
                width: 40,
                child: QuestionErrorReportAction(
                  onTap: _openErrorReport,
                  reported: _errorReported,
                  loading: _errorReportLoading,
                ),
              ),
            SizedBox(
              width: 40,
              child: FavoriteHeartButton(
                isFavorite: isFav,
                onToggle: _toggleFavorite,
              ),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                ValueListenableBuilder<Duration>(
                  valueListenable: _durationNotifier,
                  builder: (context, duration, _) {
                    final urgent = _isCountdown &&
                        (widget.tgExamMode && !widget.tgExamSolutionReview
                            ? duration.inSeconds <=
                                TgExamConstants.warningBeforeEndMinutes * 60
                            : duration.inSeconds <= 60);
                    return QuizHeaderStrip(
                      // TG denemede havuz sorularının ÖSYM damgası gösterilmez.
                      osymSordu:
                          !widget.tgExamMode && _currentQuestion.osymSordu,
                      durationText: _formatDuration(duration),
                      isCountdown: _isCountdown,
                      urgent: urgent,
                      showTimer: !widget.fromWrongNotebook,
                      questionLabel: null,
                      successLabel: widget.fromWrongNotebook ||
                              widget.tgExamMode
                          ? null
                          : _successRateLabel(),
                      successRate: widget.fromWrongNotebook || widget.tgExamMode
                          ? null
                          : _successRateMeterValue(),
                      difficultyLabel: _difficultyLabel(),
                      difficultyOnRight: widget.fromWrongNotebook,
                      attemptLabel: _viewLabelForCurrent(),
                      timerAccent: _quizAccent,
                      accentLineColors: _tgLiveExam
                          ? TgExamTheme.accentLineGradient
                          : const [
                              AppTheme.champagne,
                              AppTheme.neonEdge,
                              AppTheme.champagneLight,
                            ],
                      center: _tgLiveExam
                          ? TgSectionFilterToggle(
                              selected: _tgSectionFilter,
                              onChanged: _onTgSectionChanged,
                            )
                          : null,
                      leading: widget.fromWrongNotebook
                          ? QuizTakeNoteButton(
                              hasNote: QuestionNoteService.instance
                                  .hasNote(_currentQuestion.id),
                              onTap: _openQuestionNote,
                            )
                          : null,
                    );
                  },
                ),
                if (!widget.fromWrongNotebook) ...[
                  if (_tgLiveExam && _tgSectionFilter != TgSectionFilter.all)
                    TgSubjectFilterBar(
                      section: _tgSectionFilter,
                      selectedSubjectKey: _tgSubjectKey,
                      subjectCounts: tgSubjectCountsInSection(
                        questions: widget.questions,
                        section: _tgSectionFilter,
                      ),
                      onChanged: _onTgSubjectChanged,
                    ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      controller: _chipScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _visibleQuestionIndices().length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, listIndex) {
                        final i = _visibleQuestionIndices()[listIndex];
                        final selectedAnswer =
                            i == _currentIndex ? _selectedAnswer : _answers[i];
                        final answered = selectedAnswer != null;
                        final answeredCorrectly = answered &&
                            selectedAnswer == widget.questions[i].dogruCevap;
                        final active = i == _currentIndex;
                        final previouslySolved = !answered &&
                            !widget.tgExamMode &&
                            ContentBankService.instance
                                .isQuestionSolved(widget.questions[i].id);
                        final chip = widget.tgExamMode &&
                                !widget.tgExamSolutionReview
                            ? (
                                fill: answered
                                    ? _quizAccent.withValues(
                                        alpha: active ? 0.38 : 0.22,
                                      )
                                    : (active
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.transparent),
                                border: answered
                                    ? _quizAccent
                                    : Colors.white.withValues(
                                        alpha: active ? 1 : 0.82,
                                      ),
                                text: Colors.white,
                              )
                            : _questionChipColors(
                                answered: answered,
                                answeredCorrectly: answeredCorrectly,
                                previouslySolved: previouslySolved,
                                active: active,
                              );

                        return GestureDetector(
                          onTap: () => _goTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? _quizAccent.withValues(alpha: 0.22)
                                  : chip.fill,
                              border: Border.all(
                                color: active
                                    ? _quizAccentLight
                                    : chip.border,
                                width: active ? 1.6 : 1,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: _quizAccent
                                            .withValues(alpha: 0.22),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? _quizAccentLight
                                    : chip.text,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: widget.tgExamMode && !widget.tgExamSolutionReview
                          ? [
                              _legendDot(_quizAccent, 'İşaretli'),
                              _legendDot(Colors.white, 'Boş'),
                            ]
                          : [
                              _legendDot(Colors.white, 'Cevaplanmadı'),
                              _legendDot(_correctGreen, 'Doğru'),
                              _legendDot(_answeredWrongBurgundy, 'Yanlış'),
                              _legendDot(_previousBlue, 'Daha önce'),
                            ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Zoom ağacını çizim aç/kapa ile sökme — Impeller'da
                      // beyaz örtü / kayıp toolbar yaratıyordu.
                      QuizZoomViewport(
                        controller: _contentZoom,
                        scrollController: _scrollController,
                        zoomEnabled:
                            !_drawingEnabled && !_isFinishing,
                        padding: EdgeInsets.fromLTRB(
                          _quizContentPaddingLeft,
                          _quizContentPaddingTop,
                          20,
                          _drawingEnabled ? 72 : 16,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildQuestionBody(
                              padding: EdgeInsets.zero,
                            ),
                            if (!_drawingEnabled &&
                                (_drawings[_activeDrawingKey] ??
                                        const [])
                                    .isNotEmpty)
                              Positioned.fill(
                                child: QuizStrokeLayer(
                                  strokes:
                                      _drawings[_activeDrawingKey]!,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_drawingEnabled && !_isFinishing)
                        ListenableBuilder(
                          listenable: _scrollController,
                          builder: (context, _) {
                            final scrollOffset =
                                _scrollController.hasClients
                                    ? _scrollController.offset
                                    : 0.0;
                            final strokes =
                                _drawings[_activeDrawingKey] ??
                                    const [];
                            return QuizDrawingOverlay(
                              scrollOffset: scrollOffset,
                              contentPadding: const EdgeInsets.only(
                                left: _quizContentPaddingLeft,
                                top: _quizContentPaddingTop,
                              ),
                              strokes: strokes,
                              onStrokeComplete: (stroke) {
                                if (_isFinishing) return;
                                final surface = _showingSolution;
                                final questionId = _currentQuestion.id;
                                setState(() {
                                  final list = _drawings.putIfAbsent(
                                    _drawingStorageKey(
                                      questionId,
                                      solution: surface,
                                    ),
                                    () => [],
                                  );
                                  if (list.length >=
                                      _maxStrokesPerQuestion) {
                                    return;
                                  }
                                  list.add(stroke);
                                });
                                if (widget.fromWrongNotebook) {
                                  unawaited(
                                    _persistDrawingSurface(
                                      questionId: questionId,
                                      solution: surface,
                                    ),
                                  );
                                }
                              },
                              onUndo: () {
                                if (_isFinishing) return;
                                final surface = _showingSolution;
                                final questionId = _currentQuestion.id;
                                final key = _drawingStorageKey(
                                  questionId,
                                  solution: surface,
                                );
                                final list = _drawings[key];
                                if (list == null || list.isEmpty) {
                                  return;
                                }
                                setState(() {
                                  list.removeLast();
                                  if (list.isEmpty) {
                                    _drawings.remove(key);
                                  }
                                });
                                if (widget.fromWrongNotebook) {
                                  unawaited(
                                    _persistDrawingSurface(
                                      questionId: questionId,
                                      solution: surface,
                                    ),
                                  );
                                }
                              },
                              onClear: () {
                                final surface = _showingSolution;
                                final questionId = _currentQuestion.id;
                                setState(
                                  () => _drawings.remove(
                                    _drawingStorageKey(
                                      questionId,
                                      solution: surface,
                                    ),
                                  ),
                                );
                                if (widget.fromWrongNotebook) {
                                  unawaited(
                                    _persistDrawingSurface(
                                      questionId: questionId,
                                      solution: surface,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashOpacity,
                builder: (context, _) {
                  if (_flashOpacity.value <= 0.01) {
                    return const SizedBox.shrink();
                  }
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 1.15,
                        colors: [
                          _flashColor.withValues(alpha: _flashOpacity.value),
                          _flashColor.withValues(
                            alpha: _flashOpacity.value * 0.15,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
            QuizWrongNotebookBanner(visible: _showWrongNotebookHint),
            if (!widget.fromWrongNotebook)
              const QuizZoomDailyHint(),
            if (_noteCardOpen)
              QuizQuestionNoteCard(
                initialText:
                    QuestionNoteService.instance.noteFor(_currentQuestion.id),
                onSave: (text) => unawaited(_saveQuestionNote(text)),
                onClose: () => setState(() => _noteCardOpen = false),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomActions(),
      ),
    );
  }

  List<Widget> _matchingOptionHeaders(QuestionModel question) {
    final forced = OptionColumnLayout.forcedColumns(question.optionTable);
    if (forced == null) return const [];
    final labels = OptionColumnLayout.headersFor(
      question.soruMetni,
      question.siklar.values,
      forced,
    );
    if (labels == null || labels.isEmpty) return const [];
    return [OptionColumnHeader(labels: labels)];
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _ScenarioPassageCard extends StatelessWidget {
  final QuestionModel question;

  const _ScenarioPassageCard({required this.question});

  @override
  Widget build(BuildContext context) {
    final title = question.scenarioTitle?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title == null || title.isEmpty ? 'Olay' : title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: AppTheme.champagne,
            ),
          ),
          const SizedBox(height: 8),
          ExamScenarioPassageView(text: question.scenarioStem!),
        ],
      ),
    );
  }
}

enum _OptionTone { correct, wrong }

class _SolutionPanel extends StatelessWidget {
  final QuestionModel question;
  final String? selectedAnswer;
  final bool showFullSolution;
  final bool unlocking;
  final int dailyRemaining;
  final bool proGateRequired;
  final VoidCallback onUnlockFull;

  const _SolutionPanel({
    required this.question,
    required this.selectedAnswer,
    required this.showFullSolution,
    required this.unlocking,
    required this.dailyRemaining,
    required this.proGateRequired,
    required this.onUnlockFull,
  });

  @override
  Widget build(BuildContext context) {
    final correctKey = question.dogruCevap;
    final correctText = question.siklar[correctKey] ?? correctKey;
    final userText = selectedAnswer != null
        ? (question.siklar[selectedAnswer!] ?? selectedAnswer!)
        : null;
    final parts = splitSolutionPreview(question.cozumMetni);
    final showLockedTeaser = !showFullSolution && parts.hasLockedRemainder;
    final lockMessage = proGateRequired
        ? 'Günlük ${AdConstants.freeDetailedSolutionsPerDay} detaylı çözüm '
            'hakkın doldu.\nSınırsız adım adım çözüm için Pro Üye ol'
        : 'Bugün $dailyRemaining detaylı çözüm hakkın kaldı.\n'
            '${AdConstants.solutionUnlockAdApproxSeconds} sn reklam izleyerek '
            'devamını aç';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.champagne.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 20,
                color: AppTheme.champagne.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Text(
                showLockedTeaser ? 'Çözüm önizlemesi' : 'Çözüm',
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.champagneLight,
                ),
              ),
            ],
          ),
          if (selectedAnswer != null) ...[
            const SizedBox(height: 14),
            if (selectedAnswer != correctKey) ...[
              _AnswerChip(
                label: 'Senin cevabın',
                value: '$selectedAnswer) $userText',
                imageUrl: question.optionImageUrlFor(selectedAnswer!),
                accent: const Color(0xFFF87171),
              ),
              const SizedBox(height: 8),
            ],
            _AnswerChip(
              label: 'Doğru cevap',
              value: '$correctKey) $correctText',
              imageUrl: question.optionImageUrlFor(correctKey),
              accent: const Color(0xFF34D399),
            ),
          ],
          const SizedBox(height: 16),
          if (showFullSolution)
            ExamSolutionBlock(
              text: question.cozumMetni,
              imageUrl: question.cozumImageUrl,
            )
          else if (!parts.hasLockedRemainder) ...[
            // Kısa çözümlerde de kota sonrası reklam zorunlu — tam metin sızmaz.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Opacity(
                      opacity: 0.55,
                      child: ExamSolutionBlock(
                        text: question.cozumMetni,
                        imageUrl: question.cozumImageUrl,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.ink.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: AppTheme.champagne.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lockMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.35,
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FrostUnlockButton(
                            unlocking: unlocking,
                            proGate: proGateRequired,
                            onPressed: unlocking ? null : onUnlockFull,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ExamSolutionBlock(
              text: parts.preview,
              imageUrl: question.cozumImageUrl,
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Opacity(
                      opacity: 0.55,
                      child: ExamSolutionBlock(
                        text: parts.remainder,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.ink.withValues(alpha: 0.05),
                            AppTheme.ink.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: AppTheme.champagne.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lockMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.35,
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _FrostUnlockButton(
                            unlocking: unlocking,
                            proGate: proGateRequired,
                            onPressed: unlocking ? null : onUnlockFull,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Frost overlay CTA — Pro veya tam çözüm kilidi.
class _FrostUnlockButton extends StatelessWidget {
  final bool unlocking;
  final bool proGate;
  final VoidCallback? onPressed;

  const _FrostUnlockButton({
    required this.unlocking,
    required this.proGate,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !unlocking;
    return Opacity(
      opacity: unlocking ? 0.78 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unlocking
                ? const [
                    Color(0xFFF0E4C8),
                    Color(0xFFDCC9A0),
                  ]
                : const [
                    Color(0xFFFFF8EE),
                    Color(0xFFF5E6C8),
                    Color(0xFFE2C998),
                    Color(0xFFC9A86C),
                  ],
            stops: unlocking ? null : const [0.0, 0.35, 0.7, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFFD4AF6A),
            width: 1.15,
          ),
          boxShadow: unlocking
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.42),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            splashColor: AppTheme.ink.withValues(alpha: 0.08),
            highlightColor: AppTheme.ink.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (unlocking)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.ink,
                      ),
                    )
                  else
                    Icon(
                      proGate ? Icons.lock_rounded : Icons.play_circle_outline,
                      size: 18,
                      color: AppTheme.ink,
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      unlocking
                          ? (proGate ? 'Açılıyor…' : 'Reklam yükleniyor…')
                          : proGate
                              ? 'Pro ile tam çözümü aç'
                              : 'Reklam izle\ntam çözümü aç',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                        height: 1.15,
                        color: AppTheme.ink.withValues(
                          alpha: unlocking ? 0.7 : 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  final String label;
  final String value;
  final String? imageUrl;
  final Color accent;

  const _AnswerChip({
    required this.label,
    required this.value,
    required this.accent,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 4),
          ExamOptionView(
            text: FormattedText.stripMarkup(value),
            imageUrl: imageUrl,
          ),
        ],
      ),
    );
  }
}

class _OptionTrailing extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double? percentage;

  const _OptionTrailing({
    required this.icon,
    required this.iconColor,
    this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    if (percentage == null) {
      return Icon(icon, color: iconColor, size: 20);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 2),
        Text(
          '%${percentage!.toStringAsFixed(1)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final String? imageUrl;
  final int? forceColumns;
  final bool isSelected;
  final _OptionTone? tone;
  final double? percentage;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.imageUrl,
    this.forceColumns,
    this.tone,
    this.percentage,
  });

  static const _correct = Color(0xFF34D399);
  static const _wrong = Color(0xFFF87171);
  static const _borderWidth = 2.0;
  static const _trailingSlotWidth = 36.0;

  bool get _mathStyle =>
      forceColumns == null &&
      ExamOptionView.isMathStyleOption(text, imageUrl: imageUrl);

  @override
  Widget build(BuildContext context) {
    return _buildClassicTile(context);
  }

  Widget _buildClassicTile(BuildContext context) {
    final Color fill;
    final Color border;
    final Color badge;
    final Color badgeText;
    final List<BoxShadow>? glow;

    switch (tone) {
      case _OptionTone.correct:
        fill = _correct.withValues(alpha: 0.16);
        border = _correct;
        badge = _correct;
        badgeText = AppTheme.ink;
        glow = [
          BoxShadow(
            color: _correct.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ];
      case _OptionTone.wrong:
        fill = _wrong.withValues(alpha: 0.14);
        border = _wrong;
        badge = _wrong;
        badgeText = AppTheme.ink;
        glow = [
          BoxShadow(
            color: _wrong.withValues(alpha: 0.3),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ];
      case null:
        fill = isSelected
            ? AppTheme.champagne.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.04);
        border = isSelected
            ? AppTheme.champagne
            : Colors.white.withValues(alpha: 0.12);
        badge = isSelected
            ? AppTheme.champagne
            : Colors.white.withValues(alpha: 0.12);
        badgeText = isSelected ? AppTheme.ink : Colors.white;
        glow = null;
    }

    final hasOptionImage =
        imageUrl != null && imageUrl!.trim().isNotEmpty;
    final rowAlign = hasOptionImage
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;

    return Padding(
      padding: EdgeInsets.only(
        bottom: _mathStyle
            ? (AppBreakpoints.isTablet(context) ? 6 : 8)
            : (AppBreakpoints.isTablet(context) ? 8 : 10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: AppBreakpoints.quizOptionMinHeight(
                context,
                mathStyle: _mathStyle,
              ),
            ),
            padding: AppBreakpoints.quizOptionPadding(
              context,
              mathStyle: _mathStyle,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: border, width: _borderWidth),
              boxShadow: glow,
            ),
            child: Row(
              crossAxisAlignment: rowAlign,
              children: [
                SizedBox(
                  width: kOptionBadgeLeadingWidth,
                  child: Padding(
                    padding: EdgeInsets.only(top: hasOptionImage ? 2 : 0),
                    child: Center(
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: badge,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: badgeText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _mathStyle
                      ? Center(
                          child: ExamOptionView(
                            text: text,
                            imageUrl: imageUrl,
                            forceColumns: forceColumns,
                          ),
                        )
                      : ExamOptionView(
                          text: text,
                          imageUrl: imageUrl,
                          forceColumns: forceColumns,
                        ),
                ),
                SizedBox(
                  width: _trailingSlotWidth,
                  child: Align(
                    alignment: hasOptionImage
                        ? Alignment.topRight
                        : Alignment.centerRight,
                    child: tone == _OptionTone.correct
                        ? _OptionTrailing(
                            icon: Icons.check_rounded,
                            iconColor: _correct,
                            percentage: percentage,
                          )
                        : tone == _OptionTone.wrong
                            ? _OptionTrailing(
                                icon: Icons.close_rounded,
                                iconColor: _wrong,
                                percentage: percentage,
                              )
                            : percentage != null
                                ? Text(
                                    '%${percentage!.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.78),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _DailyMiniExitChoice { stay, submitRanking, saveOnly }

class _ResultWrongReviewButton extends StatelessWidget {
  final int wrongCount;

  const _ResultWrongReviewButton({required this.wrongCount});

  static const _wrongRed = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, true),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF6E8),
                Color(0xFFE2C998),
                AppTheme.champagne,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(1.4),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.6),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2A1218),
                  _wrongRed.withValues(alpha: 0.18),
                  const Color(0xFF1A1018),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _wrongRed.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 20,
                    color: AppTheme.champagneLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Yanlışlarımı Gör',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF6E7C3),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$wrongCount soru · hemen tekrar et',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppTheme.champagne.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRewardChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ResultRewardChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
