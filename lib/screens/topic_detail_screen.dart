import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../data/kpss_curriculum.dart';
import '../models/content_models.dart';
import '../models/quiz_result.dart';
import '../services/ad_manager.dart';
import '../services/ad_service.dart';
import '../services/content_bank_service.dart';
import '../services/content_sync_service.dart';
import '../services/question_fetch_service.dart';
import '../services/question_attempt_service.dart';
import '../services/last_study_session_service.dart';
import '../services/premium_service.dart';
import '../services/gamification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/daily_test_quota_dialog.dart';
import '../widgets/premium_gate.dart';
import '../widgets/topic_summary_swipe_deck.dart';
import '../services/summary_card_progress_service.dart';
import 'lesson_reader_screen.dart';
import 'quiz_screen.dart';

class TopicDetailScreen extends StatefulWidget {
  final KpssType kpssType;
  final String subjectId;
  final String topicId;

  const TopicDetailScreen({
    super.key,
    required this.kpssType,
    required this.subjectId,
    required this.topicId,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  final _bank = ContentBankService.instance;

  bool _refreshing = false;
  bool _startingTest = false;

  @override
  void initState() {
    super.initState();
    _bank.addListener(_onBankChanged);
    unawaited(SummaryCardProgressService.instance.initialize());
    unawaited(_refreshContent(showSuccess: false));
  }

  Future<void> _refreshContent({bool showSuccess = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final outcome = await ContentSyncService.instance.ensureFreshContent();
      if (!mounted) return;
      if (!outcome.success && outcome.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(outcome.message!)),
        );
      } else if (showSuccess && outcome.downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sorular güncellendi.')),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _bank.removeListener(_onBankChanged);
    super.dispose();
  }

  void _onBankChanged() {
    if (mounted) setState(() {});
  }

  static String _learnSectionSubtitle(
    List<TopicLessonModel> lessons,
    List<TopicSummaryCardModel> summaryCards,
  ) {
    if (lessons.isNotEmpty && summaryCards.isNotEmpty) {
      return '${lessons.length} bilgi kartı · ${summaryCards.length} özet kart';
    }
    if (lessons.isNotEmpty) {
      return '${lessons.length} bilgi kartı';
    }
    if (summaryCards.isNotEmpty) {
      return '${summaryCards.length} özet kart';
    }
    return 'Henüz bilgi kartı yok';
  }

  @override
  Widget build(BuildContext context) {
    final subject =
        KpssCurriculum.findSubject(widget.kpssType, widget.subjectId);
    final topic = KpssCurriculum.findTopic(widget.kpssType, widget.topicId);
    final tests = _bank.testsForTopic(widget.kpssType, widget.topicId);
    final stats = _bank.topicStats(widget.topicId);
    final lessons = _bank.lessonsForTopic(widget.topicId);
    final summaryCards = _bank.summaryCardsForTopic(widget.topicId);
    final learnSubtitle = _learnSectionSubtitle(lessons, summaryCards);
    final canOpenLessons = lessons.isNotEmpty;
    final progress =
        _bank.topicQuestionProgress(widget.kpssType, widget.topicId);

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(
          topic?.name ?? 'Konu',
          style:
              const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.champagne,
        backgroundColor: AppTheme.inkSoft,
        onRefresh: () => _refreshContent(showSuccess: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              subject?.name ?? '',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.champagne.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              topic?.name ?? '',
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _StatStrip(
              accuracy: stats.averageAccuracy,
              attempts: stats.attemptCount,
              net: stats.averageNet,
              unsolved: progress.unsolved,
              totalQuestions: progress.total,
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: canOpenLessons
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => LessonReaderScreen(
                                    topicName: topic?.name ?? 'Konu',
                                    lessons: lessons,
                                  ),
                                ),
                              )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Konuyu öğren',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    learnSubtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.menu_book_outlined,
                              color: canOpenLessons
                                  ? AppTheme.neonEdge.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (summaryCards.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TopicSummarySwipeDeck(cards: summaryCards),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'TESTLER',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w600,
                color: AppTheme.champagne,
              ),
            ),
            const SizedBox(height: 12),
            if (tests.isEmpty)
              Text(
                'Bu konuya henüz test eklenmemiş.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              )
            else
              ...tests.map((test) {
                final tStats = _bank.testStats(test.id);
                final isPremium = PremiumService.instance.isPremium;
                final canWatchAd = !isPremium &&
                    _bank.canWatchAdForDailyTestBonus(
                      widget.kpssType,
                      widget.subjectId,
                    );
                return _TestRow(
                  test: test,
                  stats: tStats,
                  quotaHint: !isPremium &&
                      !_bank.canStartDailySubjectTest(
                        widget.kpssType,
                        widget.subjectId,
                      ),
                  canWatchAdForBonus: canWatchAd,
                  busy: _startingTest,
                  onStart: () => _startTest(test),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<bool> _watchAdAndGrantBonus() async {
    if (!mounted) return false;
    final dialogNavigator = Navigator.of(context, rootNavigator: true);
    final kpssType = widget.kpssType;
    final subjectId = widget.subjectId;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: AppTheme.inkSoft,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.champagne),
                  SizedBox(height: 16),
                  Text(
                    'Reklam yükleniyor…',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final earned = await AdService.showRewardedAd(
      kind: AdRewardKind.dailyTestBonus,
    );
    if (dialogNavigator.mounted && dialogNavigator.canPop()) {
      dialogNavigator.pop();
    }

    if (!earned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Reklam yüklenemedi veya izlenmedi. Lütfen tekrar deneyin.'),
          ),
        );
      }
      return false;
    }

    await _bank.grantAdBonusDailyTest(kpssType, subjectId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('+1 test hakkı kazandınız!')),
      );
    }
    return _bank.canStartDailySubjectTest(kpssType, subjectId);
  }

  Future<bool> _ensureDailyTestQuota({bool preferAdGrant = false}) async {
    if (PremiumService.instance.isPremium) return true;
    if (_bank.canStartDailySubjectTest(widget.kpssType, widget.subjectId)) {
      return true;
    }

    final canWatchAd = _bank.canWatchAdForDailyTestBonus(
      widget.kpssType,
      widget.subjectId,
    );
    if (preferAdGrant && canWatchAd) {
      return _watchAdAndGrantBonus();
    }

    final subject =
        KpssCurriculum.findSubject(widget.kpssType, widget.subjectId);
    final subjectName = subject?.name ?? 'Bu ders';

    if (!mounted) return false;
    final action = await showDailyTestQuotaDialog(
      context: context,
      subjectName: subjectName,
      canWatchAd: canWatchAd,
    );

    switch (action) {
      case DailyQuotaAction.ad:
        return _watchAdAndGrantBonus();
      case DailyQuotaAction.premium:
        if (!mounted) return false;
        return PremiumGate.requirePremium(context);
      case DailyQuotaAction.cancel:
      case null:
        return false;
    }
  }

  Future<void> _startTest(
    TopicTestModel test, {
    bool preferAdGrant = false,
  }) async {
    if (_startingTest) return;
    if (!await _ensureDailyTestQuota(preferAdGrant: preferAdGrant)) return;

    setState(() => _startingTest = true);
    try {
      var fetch = await QuestionFetchService.instance.fetchForTest(test);
      if (fetch.isEmpty) {
        await ContentSyncService.instance.syncCatalog(force: true);
        fetch = await QuestionFetchService.instance.fetchForTest(test);
      }
      if (!mounted) return;
      if (fetch.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fetch.errorMessage ??
                  'Sorular yüklenemedi (${ApiConfig.baseUrl}).',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      final questions = fetch.questions;
      final saved = LastStudySessionService.instance.session;
      final resumeSameTest = saved != null &&
          saved.kind == LastStudyKind.quiz &&
          saved.testId == test.id &&
          saved.questionIds.length == questions.length &&
          saved.answers.length == questions.length;

      AdManager.instance.skipNextPageTransition();
      final result = await Navigator.of(context).push<QuizResult>(
        MaterialPageRoute<QuizResult>(
          builder: (_) => QuizScreen(
            title: test.title,
            questions: questions,
            timeLimitMinutes: test.timeLimitMinutes,
            statisticsTestId: test.id,
            initialIndex: resumeSameTest ? saved.currentIndex : 0,
            initialAnswers: resumeSameTest ? saved.answers : null,
            initialElapsed: resumeSameTest
                ? Duration(seconds: saved.elapsedSeconds)
                : Duration.zero,
            resumeMeta: QuizResumeMeta(
              testId: test.id,
              kpssType: widget.kpssType,
              subjectId: widget.subjectId,
              topicId: widget.topicId,
            ),
          ),
        ),
      );
      if (result == null || !result.completed) return;

      unawaited(
        QuestionAttemptService.instance.submit(
          testId: test.id,
          questionIds: result.questionIds,
          selectedAnswers: result.selectedAnswers,
          excludeQuestionIds: _bank.statLockedWrongQuestionIds,
        ),
      );
      await _bank.recordAttempt(
        TestAttemptModel(
          id: 'att_${DateTime.now().millisecondsSinceEpoch}',
          testId: test.id,
          topicId: widget.topicId,
          kpssType: widget.kpssType,
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
      unawaited(
        GamificationService.instance.recordTestCompleted(
          correct: result.correct,
          wrong: result.wrong,
          duration: result.duration,
        ),
      );
      if (!mounted) return;
      setState(() {});
    } catch (e, st) {
      debugPrint('_startTest error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test başlatılamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingTest = false);
    }
  }
}

class _StatStrip extends StatelessWidget {
  final double accuracy;
  final int attempts;
  final double net;
  final int unsolved;
  final int totalQuestions;

  const _StatStrip({
    required this.accuracy,
    required this.attempts,
    required this.net,
    required this.unsolved,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.neonEdge.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          colors: [
            AppTheme.neonEdge.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _cell('%${(accuracy * 100).round()}', 'Başarı'),
              _divider(),
              _cell('$attempts', 'Deneme'),
              _divider(),
              _cell(net.toStringAsFixed(1), 'Ort. net'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _cell('$totalQuestions', 'Toplam soru'),
              _divider(),
              _cell('$unsolved', 'Çözülmeyen'),
              _divider(),
              _cell(
                '${(totalQuestions - unsolved).clamp(0, totalQuestions)}',
                'Çözülen',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String v, String l) {
    return Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withValues(alpha: 0.1),
      );
}

class _TestRow extends StatelessWidget {
  final TopicTestModel test;
  final TestStatsSummary stats;
  final bool quotaHint;
  final bool canWatchAdForBonus;
  final bool busy;
  final VoidCallback onStart;

  const _TestRow({
    required this.test,
    required this.stats,
    this.quotaHint = false,
    this.canWatchAdForBonus = false,
    this.busy = false,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[
      '${ContentBankService.instance.catalogQuestionCount(test)} soru',
      if (stats.attemptCount > 0) ...[
        '${stats.attemptCount} deneme',
        'en iyi %${(stats.bestAccuracy * 100).round()}',
      ],
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      test.title,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        metaParts.join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 72,
                height: 36,
                child: TextButton(
                  onPressed: busy ? null : onStart,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.neonEdge,
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.neonEdge,
                          ),
                        )
                      : const Text('BAŞLA'),
                ),
              ),
            ],
          ),
          if (quotaHint) ...[
            const SizedBox(height: 10),
            _DailyQuotaBanner(canWatchAdForBonus: canWatchAdForBonus),
          ],
        ],
      ),
    );
  }
}

/// Günlük test hakkı dolunca satır altında belirgin uyarı.
class _DailyQuotaBanner extends StatelessWidget {
  final bool canWatchAdForBonus;

  const _DailyQuotaBanner({required this.canWatchAdForBonus});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFBBF24);
    final message = canWatchAdForBonus
        ? 'Günlük hak doldu — reklam izleyerek veya Premium ile devam edebilirsin.'
        : 'Günlük test hakkın doldu.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: amber.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: amber.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color.lerp(Colors.white, amber, 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
