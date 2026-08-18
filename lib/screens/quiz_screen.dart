import 'dart:async';

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../services/ad_manager.dart';
import '../services/ad_service.dart';
import '../services/answer_feedback_service.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../services/auth_service.dart';
import '../services/last_study_session_service.dart';
import '../services/premium_service.dart';
import '../services/question_error_report_service.dart';
import '../services/question_attempt_service.dart';
import '../services/question_rating_service.dart';
import '../theme/app_theme.dart';
import '../utils/solution_preview.dart';
import '../widgets/app_back_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/favorite_heart_button.dart';
import '../widgets/formatted_text.dart';
import '../widgets/question_error_report_button.dart';
import '../widgets/question_rating_bar.dart';
import '../widgets/osym_badge.dart';
import '../widgets/question_stem_content.dart';
import '../widgets/quiz_drawing_overlay.dart';
import '../widgets/shareable_result_card.dart';
import '../widgets/watermark_widget.dart';

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

  /// Günün Denemesi gibi tanıtım oturumları — çözüm/banner/bitiş reklamı yok.
  final bool adFreeExperience;
  final String? statisticsTestId;
  final Future<void> Function({
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
    this.adFreeExperience = false,
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
  late Duration _displayDuration;
  Timer? _ticker;
  bool _timerPaused = false;
  Duration _frozenElapsed = Duration.zero;
  bool _timeUpHandled = false;
  bool _isFinishing = false;
  QuestionRatingSummary? _ratingSummary;
  String? _ratingQuestionId;
  bool _ratingLoading = false;
  bool _ratingSaving = false;
  bool _solutionUnlocking = false;
  bool _errorReported = false;
  bool _errorReportLoading = false;
  bool _errorDailyLimitReached = false;
  final Map<String, QuestionAttemptSummary> _attemptSummaries = {};
  final Map<String, List<QuizStroke>> _drawings = {};
  bool _drawingEnabled = false;

  late final AnimationController _flashCtrl;
  late final Animation<double> _flashOpacity;
  Color _flashColor = const Color(0xFF34D399);

  static const _correctGreen = Color(0xFF34D399);
  static const _wrongRed = Color(0xFFF87171);
  static const _answeredWrongBurgundy = Color(0xFF9F1239);
  static const _previousBlue = Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    final maxIdx = widget.questions.isEmpty ? 0 : widget.questions.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIdx);
    final resume = widget.initialAnswers;
    if (resume != null && resume.length == widget.questions.length) {
      _answers = List<String?>.from(resume);
    } else {
      _answers = List<String?>.filled(widget.questions.length, null);
    }
    _selectedAnswer = widget.questions.isEmpty ? null : _answers[_currentIndex];
    final elapsed = widget.initialElapsed.isNegative
        ? Duration.zero
        : widget.initialElapsed;
    _startedAt = DateTime.now().subtract(elapsed);
    _frozenElapsed = elapsed;
    _isCountdown = widget.timeLimitMinutes > 0;
    if (_isCountdown) {
      final limit = Duration(minutes: widget.timeLimitMinutes);
      final left = limit - elapsed;
      _displayDuration = left.isNegative ? Duration.zero : left;
    } else {
      _displayDuration = elapsed;
    }
    // Devam edilen oturumda mevcut soru cevaplıysa süre bekletilir.
    _timerPaused = _selectedAnswer != null;
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.42), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 0.42, end: 0), weight: 82),
    ]).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));
    FavoritesService.instance.initialize();
    AnswerFeedbackService.instance.ensureReady();
    AdManager.instance.startTestSession(
      adFreeExperience: widget.adFreeExperience,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_selectedAnswer != null) unawaited(_loadRating());
    unawaited(_loadErrorReportState());
    unawaited(_persistProgress());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _flashCtrl.dispose();
    AdManager.instance.endTestSession();
    super.dispose();
  }

  Duration get _elapsedNow => _timerPaused
      ? _frozenElapsed
      : DateTime.now().difference(_startedAt);

  void _syncDisplayFromElapsed(Duration elapsed) {
    if (_isCountdown) {
      final limit = Duration(minutes: widget.timeLimitMinutes);
      final left = limit - elapsed;
      _displayDuration = left.isNegative ? Duration.zero : left;
    } else {
      _displayDuration = elapsed;
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

  /// Cevapsız soruda süre akar; cevaplı soruda bekler (açıklama okurken yanmaz).
  void _syncTimerForCurrentQuestion() {
    if (_selectedAnswer != null) {
      _pauseTimer();
    } else {
      _resumeTimer();
    }
  }

  Future<void> _persistProgress() async {
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
    await widget.onProgress?.call(
      answers: _answers,
      currentIndex: _currentIndex,
      elapsed: _elapsedNow,
    );
  }

  void _selectAnswer(String key) {
    if (_selectedAnswer == key) return;
    final isCorrect = key == _currentQuestion.dogruCevap;
    setState(() {
      _selectedAnswer = key;
      _answers[_currentIndex] = key;
      _pauseTimer();
    });
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
    final testId = widget.statisticsTestId;
    if (testId == null || testId.isEmpty) return;
    final questionId = _currentQuestion.id;
    final summary = await QuestionAttemptService.instance.submitQuestion(
      testId: testId,
      questionId: questionId,
      selectedOption: selectedOption,
    );
    if (!mounted || summary == null || _currentQuestion.id != questionId) {
      return;
    }
    setState(() => _attemptSummaries[questionId] = summary);
  }

  void _tick() {
    if (!mounted || _timerPaused) return;
    final elapsed = DateTime.now().difference(_startedAt);
    if (_isCountdown) {
      final limit = Duration(minutes: widget.timeLimitMinutes);
      final left = limit - elapsed;
      setState(() {
        _displayDuration = left.isNegative ? Duration.zero : left;
      });
      if (left <= Duration.zero && !_timeUpHandled) {
        _timeUpHandled = true;
        _onTimeUp();
      }
    } else {
      setState(() => _displayDuration = elapsed);
    }
  }

  Future<void> _onTimeUp() async {
    if (!mounted) return;
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
    final topic = widget.questions.isEmpty
        ? ''
        : widget.questions.first.konuAdi.trim();
    if (topic.isNotEmpty) return topic;
    return widget.title.trim().isEmpty ? 'Test Sonucu' : widget.title;
  }

  int get _visibleAttemptCount =>
      _attemptSummaries[_currentQuestion.id]?.attemptCount ??
      _currentQuestion.attemptCount;

  Map<String, double>? get _optionPercentages =>
      _attemptSummaries[_currentQuestion.id]?.optionPercentages;

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

  QuizResult _buildResult({required bool completed}) {
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
    await _persistProgress();
    if (!mounted) return false;
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

  void _popWithResult({required bool completed}) {
    _answers[_currentIndex] = _selectedAnswer;
    _isFinishing = true;
    AdManager.instance.endTestSession();
    if (completed) {
      unawaited(LastStudySessionService.instance.clearQuizProgress());
    } else {
      unawaited(_persistProgress());
    }
    Navigator.of(context).pop(_buildResult(completed: completed));
  }

  void _goTo(int index) {
    _answers[_currentIndex] = _selectedAnswer;
    setState(() {
      _currentIndex = index;
      _selectedAnswer = _answers[index];
      _showingSolution = false;
      _solutionUnlocking = false;
      _resetRatingState();
      _resetErrorReportState();
      _syncTimerForCurrentQuestion();
    });
    unawaited(_persistProgress());
    if (_selectedAnswer != null) unawaited(_loadRating());
    unawaited(_loadErrorReportState());
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
    final questionId = _currentQuestion.id;
    if (!QuestionErrorReportService.canReport(questionId) ||
        !AuthService.instance.hasBackendSession) {
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
    if (!AuthService.instance.hasBackendSession) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bildirmek için giriş yapın.')),
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
    await showQuestionErrorReportSheet(
      context: context,
      onSubmit: (category, note) async {
        await QuestionErrorReportService.instance.submit(
          questionId: questionId,
          category: category,
          note: note,
        );
        if (!mounted) return;
        setState(() {
          _errorReported = true;
          _errorDailyLimitReached = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teşekkürler — bildiriminiz incelenecek.'),
          ),
        );
      },
    );
  }

  Future<void> _loadRating() async {
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
    final fullUnlocked = _isSolutionFullyUnlocked;
    if (fullUnlocked) {
      setState(() => _showingSolution = true);
      return;
    }
    setState(() => _showingSolution = true);
  }

  bool get _isSolutionFullyUnlocked {
    return PremiumService.instance.isPremium ||
        AdManager.instance.isSolutionUnlocked(_currentQuestion.id);
  }

  Future<void> _unlockFullSolution() async {
    if (_isSolutionFullyUnlocked) {
      setState(() => _showingSolution = true);
      return;
    }

    setState(() => _solutionUnlocking = true);
    final success = await AdService.showRewardedAd(
      kind: AdRewardKind.solutionUnlock,
      questionId: _currentQuestion.id,
    );

    if (!mounted) return;
    setState(() => _solutionUnlocking = false);

    if (success) {
      setState(() => _showingSolution = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reklam yüklenemedi veya izlenmedi. Önizleme açık kaldı.',
          ),
        ),
      );
    }
  }

  void _nextQuestion() {
    if (_isFinishing) return;
    _answers[_currentIndex] = _selectedAnswer;
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = _answers[_currentIndex];
        _showingSolution = false;
        _solutionUnlocking = false;
        _resetRatingState();
        _resetErrorReportState();
        _syncTimerForCurrentQuestion();
      });
      unawaited(_persistProgress());
      if (_selectedAnswer != null) unawaited(_loadRating());
      unawaited(_loadErrorReportState());
    } else {
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
    if (blankCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: const Text(
            'Boş sorular var',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Text(
            blankCount == 1
                ? '1 soruyu boş bıraktınız. Testi yine de bitirmek istiyor musunuz?'
                : '$blankCount soruyu boş bıraktınız. Testi yine de bitirmek istiyor musunuz?',
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
              child: const Text('Yine de bitir'),
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
    }
    await _finishTest();
  }

  void _previousQuestion() {
    if (_isFinishing || _currentIndex <= 0) return;
    _answers[_currentIndex] = _selectedAnswer;
    setState(() {
      _currentIndex--;
      _selectedAnswer = _answers[_currentIndex];
      _showingSolution = false;
      _solutionUnlocking = false;
      _resetRatingState();
      _resetErrorReportState();
      _syncTimerForCurrentQuestion();
    });
    unawaited(_persistProgress());
    if (_selectedAnswer != null) unawaited(_loadRating());
    unawaited(_loadErrorReportState());
  }

  Future<void> _showResultDialog(QuizResult result) {
    final shareKey = GlobalKey();
    var sharing = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.inkSoft,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _resultHeading,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.champagne,
                  ),
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
                    const SizedBox(height: 12),
                    Text(
                      'Soru başı ort. '
                      '${QuizResult.formatDuration(result.averageQuestionDuration)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
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
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
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
    );
  }

  Future<void> _finishTest() async {
    if (_isFinishing || !mounted) return;
    setState(() => _isFinishing = true);
    _ticker?.cancel();
    _answers[_currentIndex] = _selectedAnswer;
    final result = _buildResult(completed: true);

    AdManager.instance.endTestSession();
    await LastStudySessionService.instance.clearQuizProgress();
    await AdManager.instance.showTestCompletionInterstitial();
    if (!mounted) return;

    if (!widget.skipResultDialog) {
      await _showResultDialog(result);
      if (!mounted) return;
    }

    Navigator.of(context).pop(result);
  }

  Widget _buildBottomActions() {
    final bannerAd = AdManager.instance.bannerAd;
    final isLast = _currentIndex >= widget.questions.length - 1;
    final canGoBack = _currentIndex > 0 && !_isFinishing;
    final canAdvance = !_isFinishing;

    ButtonStyle navOutlineStyle({required bool enabled}) =>
        OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.28),
          minimumSize: const Size(0, 46),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: enabled ? 0.28 : 0.12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        );

    final solutionStyle = OutlinedButton.styleFrom(
      foregroundColor: AppTheme.champagneLight,
      minimumSize: const Size(0, 46),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      side: BorderSide(color: AppTheme.champagne.withValues(alpha: 0.45)),
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );

    return SafeArea(
      top: false,
      child: Material(
        color: AppTheme.ink,
        elevation: 8,
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _showingSolution
                          ? () => setState(() => _showingSolution = false)
                          : _requestSolution,
                      style: solutionStyle,
                      child: Text(
                        _showingSolution ? 'Çözümü Gizle' : 'Çözümü Gör',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: isLast
                        ? FilledButton(
                            onPressed: canAdvance ? _nextQuestion : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.champagne,
                              foregroundColor: AppTheme.ink,
                              disabledBackgroundColor:
                                  AppTheme.champagne.withValues(alpha: 0.35),
                              disabledForegroundColor:
                                  AppTheme.ink.withValues(alpha: 0.45),
                              minimumSize: const Size(0, 46),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text(
                              'Bitir',
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
            if (bannerAd != null)
              SizedBox(
                width: double.infinity,
                height: bannerAd.size.height.toDouble(),
                child: AdWidget(ad: bannerAd),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = FavoritesService.instance.isFavorite(_currentQuestion.id);
    final urgent = _isCountdown && _displayDuration.inSeconds <= 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          _popWithResult(completed: false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.ink,
        appBar: AppBar(
          backgroundColor: AppTheme.inkSoft,
          foregroundColor: Colors.white,
          centerTitle: false,
          titleSpacing: 8,
          leading: AppBackButton(onPressed: () async {
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) {
              _popWithResult(completed: false);
            }
          }),
          title: Row(
            children: [
              const Spacer(),
              Flexible(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.champagne,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          toolbarHeight: 56,
          actionsPadding: const EdgeInsets.only(right: 2),
          actions: [
            SizedBox(
              width: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: _drawingEnabled ? 'Çizimi kapat' : 'Çizim modu',
                onPressed: () =>
                    setState(() => _drawingEnabled = !_drawingEnabled),
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
                QuizHeaderStrip(
                  osymSordu: _currentQuestion.osymSordu,
                  durationText: _formatDuration(_displayDuration),
                  isCountdown: _isCountdown,
                  urgent: urgent,
                  questionLabel:
                      'Soru ${_currentIndex + 1} / ${widget.questions.length}',
                  difficultyLabel: _difficultyLabel(),
                  attemptLabel: '$_visibleAttemptCount kişi cevapladı',
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.questions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final selectedAnswer =
                          i == _currentIndex ? _selectedAnswer : _answers[i];
                      final answered = selectedAnswer != null;
                      final answeredCorrectly = answered &&
                          selectedAnswer == widget.questions[i].dogruCevap;
                      final active = i == _currentIndex;
                      final previouslySolved = !answered &&
                          ContentBankService.instance
                              .isQuestionSolved(widget.questions[i].id);
                      final chip = _questionChipColors(
                        answered: answered,
                        answeredCorrectly: answeredCorrectly,
                        previouslySolved: previouslySolved,
                        active: active,
                      );

                      return GestureDetector(
                        onTap: () => _goTo(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: chip.fill,
                            border: Border.all(
                              color: chip.border,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: chip.text,
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
                    children: [
                      _legendDot(Colors.white, 'Cevaplanmadı'),
                      _legendDot(_correctGreen, 'Doğru'),
                      _legendDot(_answeredWrongBurgundy, 'Yanlış'),
                      _legendDot(_previousBlue, 'Daha önce'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentQuestion.hasScenarioPassage) ...[
                          _ScenarioPassageCard(question: _currentQuestion),
                          const SizedBox(height: 16),
                        ],
                        QuestionStemPanel(
                          child: WatermarkWidget(
                            opacity: 0.26,
                            child: QuestionStemContent(
                              stem: _currentQuestion.soruMetni,
                              imageUrl: _currentQuestion.imageUrl,
                              sekilKodu: _currentQuestion.sekilKodu,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_showingSolution)
                          _SolutionPanel(
                            question: _currentQuestion,
                            selectedAnswer: _selectedAnswer,
                            showFullSolution: _isSolutionFullyUnlocked,
                            unlocking: _solutionUnlocking,
                            onUnlockFull: _unlockFullSolution,
                          )
                        else
                          ..._currentQuestion.siklar.entries.map(
                            (entry) {
                              final selected = _selectedAnswer == entry.key;
                              final revealed = _selectedAnswer != null;
                              final isCorrectKey =
                                  entry.key == _currentQuestion.dogruCevap;
                              _OptionTone? tone;
                              if (revealed) {
                                if (isCorrectKey) {
                                  tone = _OptionTone.correct;
                                } else if (selected) {
                                  tone = _OptionTone.wrong;
                                }
                              }
                              return _OptionTile(
                                label: entry.key,
                                text: entry.value,
                                isSelected: selected,
                                tone: tone,
                                percentage: revealed
                                    ? _visibleOptionPercentages[entry.key]
                                    : null,
                                onTap: () => _selectAnswer(entry.key),
                              );
                            },
                          ),
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
            if (_drawingEnabled)
              QuizDrawingOverlay(
                strokes: _drawings[_currentQuestion.id] ?? const [],
                onStrokeComplete: (stroke) => setState(
                  () => _drawings
                      .putIfAbsent(_currentQuestion.id, () => [])
                      .add(stroke),
                ),
                onClear: () => setState(
                  () => _drawings.remove(_currentQuestion.id),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomActions(),
      ),
    );
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
          FormattedText(
            question.scenarioStem!,
            paragraphLayout: true,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: Colors.white,
            ),
          ),
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
  final VoidCallback onUnlockFull;

  const _SolutionPanel({
    required this.question,
    required this.selectedAnswer,
    required this.showFullSolution,
    required this.unlocking,
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
                accent: const Color(0xFFF87171),
              ),
              const SizedBox(height: 8),
            ],
            _AnswerChip(
              label: 'Doğru cevap',
              value: '$correctKey) $correctText',
              accent: const Color(0xFF34D399),
            ),
          ],
          const SizedBox(height: 16),
          if (showFullSolution || !parts.hasLockedRemainder)
            FormattedText(
              question.cozumMetni,
              preserveLineBreaks: true,
              style: TextStyle(
                height: 1.55,
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          else ...[
            FormattedText(
              parts.preview,
              preserveLineBreaks: true,
              style: TextStyle(
                height: 1.55,
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.9),
              ),
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
                      child: FormattedText(
                        parts.remainder,
                        preserveLineBreaks: true,
                        style: TextStyle(
                          height: 1.55,
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
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
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: AppTheme.champagne.withValues(alpha: 0.9),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Devamını görmek için\n30 sn reklam izleyin',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.35,
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: unlocking ? null : onUnlockFull,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.champagne,
                              foregroundColor: AppTheme.ink,
                            ),
                            icon: unlocking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.ink,
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_circle_outline,
                                    size: 20,
                                  ),
                            label: Text(
                              unlocking
                                  ? 'Reklam yükleniyor…'
                                  : 'Reklam izle — tam çözümü aç',
                            ),
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

class _AnswerChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _AnswerChip({
    required this.label,
    required this.value,
    required this.accent,
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
          FormattedText(
            FormattedText.wrapBareLatex(FormattedText.stripMarkup(value)),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final _OptionTone? tone;
  final double? percentage;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
    this.tone,
    this.percentage,
  });

  static const _correct = Color(0xFF34D399);
  static const _wrong = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    final Color badge;
    final Color badgeText;
    final double borderWidth;
    final List<BoxShadow>? glow;

    switch (tone) {
      case _OptionTone.correct:
        fill = _correct.withValues(alpha: 0.16);
        border = _correct;
        badge = _correct;
        badgeText = AppTheme.ink;
        borderWidth = 2;
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
        borderWidth = 2;
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
        borderWidth = isSelected ? 2 : 1;
        glow = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(color: border, width: borderWidth),
              boxShadow: glow,
            ),
            child: Row(
              children: [
                CircleAvatar(
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
                const SizedBox(width: 12),
                Expanded(
                  child: FormattedText(
                    FormattedText.wrapBareLatex(
                      FormattedText.stripMarkup(text),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (tone == _OptionTone.correct)
                  const Icon(Icons.check_rounded, color: _correct, size: 20)
                else if (tone == _OptionTone.wrong)
                  const Icon(Icons.close_rounded, color: _wrong, size: 20),
                if (percentage != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '%${percentage!.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
