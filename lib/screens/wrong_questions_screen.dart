import 'dart:async';

import 'package:flutter/material.dart';

import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../services/ad_manager.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../services/question_fetch_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../services/kpss_preference_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/pro_upsell_sheet.dart';
import '../widgets/wrong_notebook/wrong_notebook_empty_state.dart';
import '../widgets/wrong_notebook/wrong_notebook_header.dart';
import '../widgets/wrong_notebook/wrong_notebook_practice_bar.dart';
import '../widgets/wrong_notebook/wrong_notebook_question_card.dart';
import '../widgets/wrong_notebook/wrong_notebook_stats_row.dart';
import '../widgets/wrong_notebook/wrong_notebook_subject_filter.dart';
import 'quiz_screen.dart';
import 'smart_review_screen.dart';

/// Konu testlerinde yanlış yapılan sorular (doğru çözünce listeden düşmez).
class WrongQuestionsScreen extends StatefulWidget {
  const WrongQuestionsScreen({super.key});

  @override
  State<WrongQuestionsScreen> createState() => _WrongQuestionsScreenState();
}

class _WrongQuestionsScreenState extends State<WrongQuestionsScreen> {
  String? _subjectFilter;
  bool _hydrating = false;
  String? _similarLoadingId;

  @override
  void initState() {
    super.initState();
    FavoritesService.instance.initialize();
    unawaited(_hydrateMissingBodies());
  }

  Future<void> _hydrateMissingBodies() async {
    final missing = ContentBankService.instance.unresolvedWrongQuestionIds;
    if (missing.isEmpty || _hydrating) return;
    setState(() => _hydrating = true);
    try {
      await QuestionFetchService.instance.fetchByIds(missing);
      await ContentBankService.instance.persistWrongQuestionBodiesNow();
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  Future<void> _afterQuiz(QuizResult? result) async {
    if (result == null || !result.completed) return;
    await ContentBankService.instance.updateAnswerOutcomes(
      wrongQuestionIds: result.wrongQuestionIds,
      correctQuestionIds: result.correctQuestionIds,
    );
  }

  Future<void> _toggleFavorite(String questionId) async {
    await FavoritesService.instance.toggle(questionId);
    if (mounted) setState(() {});
  }

  Future<void> _openQuestion(BuildContext context, String questionId) async {
    final bank = ContentBankService.instance;
    final question = bank.questionById(questionId);
    if (question == null) return;

    final test = bank.testContainingQuestion(questionId);
    late final List<QuestionModel> questions;
    late final String title;
    var initialIndex = 0;
    var timeLimit = 0;

    if (test != null) {
      questions = bank.questionsForTest(test);
      title = test.title;
      timeLimit = test.timeLimitMinutes;
      initialIndex = questions.indexWhere((q) => q.id == questionId);
      if (initialIndex < 0) initialIndex = 0;
    } else {
      questions = [question];
      title = 'Yanlış soru';
    }

    AdManager.instance.skipNextPageTransition();
    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(
          title: title,
          questions: questions,
          timeLimitMinutes: timeLimit,
          initialIndex: initialIndex,
        ),
      ),
    );
    await _afterQuiz(result);
    if (mounted) setState(() {});
  }

  Future<void> _openSimilar(
    BuildContext context,
    QuestionModel question,
  ) async {
    if (!PremiumService.instance.isPremium) {
      await ProUpsellSheet.show(context);
      return;
    }
    if (_similarLoadingId != null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: AppTheme.inkSoft,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.champagne.withValues(alpha: 0.16),
                            border: Border.all(
                              color: AppTheme.champagne.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Benzer sorular',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bu yanlış sorunun metnine en yakın yayınlanmış '
                      'sorular vektör benzerliği ile sıralanır. Yanlış '
                      'sorusunun kendisi açılmaz; pratik için ayrı bir set gelir.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Vazgeç'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.champagne,
                              foregroundColor: AppTheme.ink,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Getir',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(this.context);
    final messenger = ScaffoldMessenger.of(this.context);
    setState(() => _similarLoadingId = question.id);
    List<QuestionModel> similar = const [];
    try {
      similar = await QuestionFetchService.instance.fetchSimilar(
        question.id,
      );
    } finally {
      if (mounted) setState(() => _similarLoadingId = null);
    }
    if (!mounted) return;
    if (similar.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Benzer soru bulunamadı.')),
      );
      return;
    }

    AdManager.instance.skipNextPageTransition();
    final result = await navigator.push<QuizResult>(
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(
          title: 'Benzer sorular',
          questions: similar,
        ),
      ),
    );
    await _afterQuiz(result);
    if (mounted) setState(() {});
  }

  Future<void> _practiceAll(List<QuestionModel> questions) async {
    if (questions.isEmpty) return;
    AdManager.instance.skipNextPageTransition();
    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(
          title: 'Yanlış Pratik',
          questions: questions,
        ),
      ),
    );
    await _afterQuiz(result);
    if (mounted) setState(() {});
  }

  List<QuestionModel> _filteredQuestions(
    ContentBankService bank,
    List<QuestionModel> all,
  ) {
    if (_subjectFilter == null) return all;
    return all.where((q) => q.dersAdi == _subjectFilter).toList();
  }

  Map<String, List<QuestionModel>> _groupBySubject(List<QuestionModel> questions) {
    final grouped = <String, List<QuestionModel>>{};
    for (final q in questions) {
      grouped.putIfAbsent(q.dersAdi, () => []).add(q);
    }
    final keys = grouped.keys.toList()..sort();
    return {for (final k in keys) k: grouped[k]!};
  }

  List<(String subject, int count)> _subjectSummary(List<QuestionModel> all) {
    final counts = <String, int>{};
    for (final q in all) {
      counts[q.dersAdi] = (counts[q.dersAdi] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => (e.key, e.value)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ContentBankService.instance,
        FavoritesService.instance,
        PlayBillingService.instance.premiumNotifier,
      ]),
      builder: (context, _) {
        final bank = ContentBankService.instance;
        final favs = FavoritesService.instance;
        final kpssType = KpssPreferenceService.instance.kpssType;
        final allQuestions = bank.questionsByIds(bank.wrongQuestionIds.toList());
        final subjects = _subjectSummary(allQuestions);
        final questions = _filteredQuestions(bank, allQuestions);
        final grouped = _groupBySubject(questions);

        if (_subjectFilter != null &&
            !subjects.any((s) => s.$1 == _subjectFilter)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _subjectFilter = null);
          });
        }

        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: AppBar(
            backgroundColor: AppTheme.page(context),
            foregroundColor: AppTheme.onPage(context),
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            centerTitle: false,
            titleSpacing: 0,
            leading: const AppBackButton(),
            title: WrongNotebookHeaderTitle(
              questionCount: allQuestions.length,
              subjectCount: subjects.length,
            ),
            actions: [
              if (allQuestions.isNotEmpty)
                WrongNotebookHeaderPill(
                  label: 'Akıllı Tekrar',
                  icon: Icons.psychology_alt_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SmartReviewScreen(kpssType: kpssType),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 12),
            ],
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.pageTop(context),
                  AppTheme.page(context),
                  AppTheme.pageDeep(context),
                ],
              ),
            ),
            child: allQuestions.isEmpty
                ? (_hydrating
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppTheme.champagne,
                          ),
                        ),
                      )
                    : WrongNotebookEmptyState(kpssType: kpssType))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WrongNotebookStatsRow(
                        questionCount: allQuestions.length,
                        subjectCount: subjects.length,
                        topSubject: subjects.isNotEmpty ? subjects.first.$1 : null,
                        topSubjectCount:
                            subjects.isNotEmpty ? subjects.first.$2 : null,
                      ),
                      const WrongNotebookInsightBanner(),
                      WrongNotebookSubjectFilter(
                        subjects: subjects,
                        totalCount: allQuestions.length,
                        selectedSubject: _subjectFilter,
                        onChanged: (value) =>
                            setState(() => _subjectFilter = value),
                      ),
                      Expanded(
                        child: questions.isEmpty
                            ? Center(
                                child: Text(
                                  'Bu derste yanlış soru yok.',
                                  style: TextStyle(
                                    color: AppTheme.slate.withValues(alpha: 0.6),
                                  ),
                                ),
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                children: [
                                  for (final entry in grouped.entries) ...[
                                    WrongNotebookSubjectHeader(
                                      subject: entry.key,
                                      count: entry.value.length,
                                    ),
                                    for (final q in entry.value)
                                      WrongNotebookQuestionCard(
                                        question: q,
                                        isFavorite: favs.isFavorite(q.id),
                                        similarLoading:
                                            _similarLoadingId == q.id,
                                        showProBadge:
                                            !PremiumService.instance.isPremium,
                                        onToggleFavorite: () =>
                                            _toggleFavorite(q.id),
                                        onSimilar: () => _openSimilar(
                                          context,
                                          q,
                                        ),
                                        onTap: () => _openQuestion(
                                          context,
                                          q.id,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                      ),
                      if (questions.isNotEmpty)
                        WrongNotebookPracticeBar(
                          questionCount: questions.length,
                          onPracticeAll: () => _practiceAll(questions),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
