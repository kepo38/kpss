import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/kpss_curriculum.dart';
import '../models/content_models.dart';
import '../models/quiz_result.dart';
import '../models/special_test_models.dart';
import '../services/ad_manager.dart';
import '../services/ad_service.dart';
import '../services/content_bank_service.dart';
import '../services/gamification_service.dart';
import '../services/last_study_session_service.dart';
import '../services/premium_service.dart';
import '../services/question_attempt_service.dart';
import '../services/question_fetch_service.dart';
import '../services/special_tests_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/premium_gate.dart';
import 'quiz_screen.dart';

enum _DailyQuotaAction { cancel, ad, premium }

/// Özel Testler → Haritalarla Coğrafya.
class SpecialMapGeographyScreen extends StatefulWidget {
  final KpssType kpssType;
  final SpecialTestCategory category;

  const SpecialMapGeographyScreen({
    super.key,
    required this.kpssType,
    required this.category,
  });

  @override
  State<SpecialMapGeographyScreen> createState() =>
      _SpecialMapGeographyScreenState();
}

class _SpecialMapGeographyScreenState extends State<SpecialMapGeographyScreen> {
  final _bank = ContentBankService.instance;
  final _svc = SpecialTestsService.instance;
  bool _startingTest = false;

  static const _subjectId = 'cografya';

  @override
  void initState() {
    super.initState();
    _bank.addListener(_onChanged);
    _svc.addListener(_onChanged);
  }

  @override
  void dispose() {
    _bank.removeListener(_onChanged);
    _svc.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  SpecialTestCategory get _category =>
      _svc.categoryById(widget.category.id) ?? widget.category;

  Future<bool> _watchAdAndGrantBonus() async {
    if (!mounted) return false;
    final dialogNavigator = Navigator.of(context, rootNavigator: true);
    final kpssType = widget.kpssType;
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

    await _bank.grantAdBonusDailyTest(kpssType, _subjectId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('+1 test hakkı kazandınız!')),
      );
    }
    return _bank.canStartDailySubjectTest(kpssType, _subjectId);
  }

  Future<bool> _ensureDailyTestQuota({bool preferAdGrant = false}) async {
    if (PremiumService.instance.isPremium) return true;
    if (_bank.canStartDailySubjectTest(widget.kpssType, _subjectId)) {
      return true;
    }

    final canWatchAd = _bank.canWatchAdForDailyTestBonus(
      widget.kpssType,
      _subjectId,
    );
    if (preferAdGrant && canWatchAd) {
      return _watchAdAndGrantBonus();
    }

    final subject = KpssCurriculum.findSubject(widget.kpssType, _subjectId);
    final subjectName = subject?.name ?? 'Coğrafya';

    if (!mounted) return false;
    final action = await showDialog<_DailyQuotaAction>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.inkSoft,
        title: const Text(
          'Günlük test limiti',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          canWatchAd
              ? '$subjectName dersinde bugünkü test hakkınızı kullandınız.\n\n'
                  'Ücretsiz planda her dersten günde 1 test çözebilirsiniz. '
                  '30 saniyelik reklam izleyerek +1 ek test hakkı kazanabilir '
                  'veya Premium\'a geçebilirsiniz.'
              : '$subjectName dersinde bugünkü test ve reklam bonusu '
                  'hakkınızı kullandınız.\n\n'
                  'Sınırsız test için Premium\'a geçin.',
          style: TextStyle(
            height: 1.45,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _DailyQuotaAction.cancel),
            child: const Text('Vazgeç'),
          ),
          if (canWatchAd)
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _DailyQuotaAction.ad),
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Reklam izle — +1 test hakkı kazan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.neonEdge,
                side:
                    BorderSide(color: AppTheme.neonEdge.withValues(alpha: 0.6)),
              ),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DailyQuotaAction.premium),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: AppTheme.ink,
            ),
            child: const Text('Premium'),
          ),
        ],
      ),
    );

    switch (action) {
      case _DailyQuotaAction.ad:
        return _watchAdAndGrantBonus();
      case _DailyQuotaAction.premium:
        if (!mounted) return false;
        return PremiumGate.requirePremium(context);
      case _DailyQuotaAction.cancel:
      case null:
        return false;
    }
  }

  Future<void> _startTest(
    SpecialTestItem test, {
    bool preferAdGrant = false,
  }) async {
    if (_startingTest) return;
    if (!await _ensureDailyTestQuota(preferAdGrant: preferAdGrant)) return;

    setState(() => _startingTest = true);
    try {
      var questions = await QuestionFetchService.instance.fetchByIds(
        test.questionIds,
      );
      if (questions.isEmpty) {
        await _svc.refresh();
        questions = await QuestionFetchService.instance.fetchByIds(
          test.questionIds,
        );
      }
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sorular yüklenemedi. API adresini kontrol edin.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

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
            statisticsTestId: test.id,
            initialIndex: resumeSameTest ? saved.currentIndex : 0,
            initialAnswers: resumeSameTest ? saved.answers : null,
            initialElapsed: resumeSameTest
                ? Duration(seconds: saved.elapsedSeconds)
                : Duration.zero,
            resumeMeta: QuizResumeMeta(
              testId: test.id,
              kpssType: widget.kpssType,
              subjectId: _subjectId,
              topicId: SpecialTestsService.mapGeographyTopicId,
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
        ),
      );
      await _bank.recordAttempt(
        TestAttemptModel(
          id: 'att_${DateTime.now().millisecondsSinceEpoch}',
          testId: test.id,
          topicId: SpecialTestsService.mapGeographyTopicId,
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
      debugPrint('_startSpecialMapTest error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test başlatılamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tests = _category.tests;
    const bronze = Color(0xFFC4A35A);

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.page(context),
        foregroundColor: AppTheme.onPage(context),
        leading: const AppBackButton(),
        title: Text(
          _category.title,
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.8,
            color: AppTheme.onPage(context),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.champagne,
        backgroundColor: AppTheme.surfaceCard(context),
        onRefresh: _svc.refresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          itemCount: tests.isEmpty ? 1 : tests.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    'HARİTA OKUMA BECERİSİ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppTheme.mutedOnPage(context),
                    ),
                  ),
                ),
              );
            }
            if (tests.isEmpty) {
              return Text(
                'Henüz haritalı coğrafya sorusu yok.',
                style: TextStyle(color: AppTheme.mutedOnPage(context)),
              );
            }
            final test = tests[index - 1];
            final stats = _bank.testStats(test.id);
            final quotaHint = !PremiumService.instance.isPremium &&
                !_bank.canStartDailySubjectTest(widget.kpssType, _subjectId);
            final canWatchAd = _bank.canWatchAdForDailyTestBonus(
              widget.kpssType,
              _subjectId,
            );
            return _SpecialTestCard(
              test: test,
              stats: stats,
              bronze: bronze,
              quotaHint: quotaHint,
              canWatchAdForBonus: canWatchAd,
              busy: _startingTest,
              onStart: () => _startTest(
                test,
                preferAdGrant: quotaHint && canWatchAd,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SpecialTestCard extends StatelessWidget {
  final SpecialTestItem test;
  final TestStatsSummary stats;
  final Color bronze;
  final bool quotaHint;
  final bool canWatchAdForBonus;
  final bool busy;
  final VoidCallback onStart;

  const _SpecialTestCard({
    required this.test,
    required this.stats,
    required this.bronze,
    this.quotaHint = false,
    this.canWatchAdForBonus = false,
    this.busy = false,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      '${test.questionCount} soru',
      if (stats.attemptCount > 0) ...[
        '${stats.attemptCount} deneme',
        'en iyi %${(stats.bestAccuracy * 100).round()}',
      ],
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF243836),
            Color(0xFF152422),
          ],
        ),
        border: Border.all(color: bronze.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onStart,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta.join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: bronze.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onStart,
                  style: TextButton.styleFrom(foregroundColor: bronze),
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          quotaHint
                              ? (canWatchAdForBonus ? 'Reklam' : 'Kilit')
                              : 'Başla',
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
