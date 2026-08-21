import 'dart:async';

import 'package:flutter/material.dart';

import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../services/ad_manager.dart';
import '../services/auth_service.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../services/question_fetch_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../services/kpss_preference_service.dart';
import '../services/manual_question_service.dart';
import '../theme/app_theme.dart';
import '../widgets/account_link_card.dart';
import '../widgets/app_back_button.dart';
import '../widgets/pro_upsell_sheet.dart';
import '../widgets/question_stem_content.dart';
import '../widgets/wrong_notebook/wrong_notebook_empty_state.dart';
import '../widgets/wrong_notebook/wrong_notebook_header.dart';
import '../widgets/wrong_notebook/wrong_notebook_practice_bar.dart';
import '../widgets/wrong_notebook/wrong_notebook_question_card.dart';
import '../widgets/wrong_notebook/wrong_notebook_remove_toast.dart';
import '../widgets/wrong_notebook/wrong_notebook_stats_row.dart';
import '../widgets/wrong_notebook/wrong_notebook_subject_filter.dart';
import 'quiz_screen.dart';
import 'smart_review_screen.dart';
import 'wrong_notebook_manual_screen.dart';

/// Konu testlerinde yanlış yapılan sorular; kullanıcı istediğini kaldırabilir.
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
    unawaited(ManualQuestionService.instance.initialize());
    unawaited(_hydrateMissingBodies());
  }

  @override
  void dispose() {
    WrongNotebookRemoveToast.hide();
    super.dispose();
  }

  Future<void> _hydrateMissingBodies() async {
    final missing = ContentBankService.instance.unresolvedWrongQuestionIds;
    if (missing.isEmpty || _hydrating) return;
    setState(() => _hydrating = true);
    try {
      await QuestionFetchService.instance.fetchByIds(missing);
      await ContentBankService.instance.persistWrongQuestionBodiesNow();
    } catch (e, st) {
      debugPrint('Wrong notebook hydrate error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bazı yanlış sorular yüklenemedi. Tekrar dene.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  Future<void> _afterQuiz(QuizResult? result) async {
    if (result == null || !result.completed) return;
    await ContentBankService.instance.updateAnswerOutcomes(
      wrongQuestionIds: result.wrongQuestionIds,
      correctQuestionIds: result.correctQuestionIds,
      questionIds: result.questionIds,
      selectedAnswers: result.selectedAnswers,
    );
  }

  Future<void> _toggleFavorite(String questionId) async {
    await FavoritesService.instance.toggle(questionId);
    if (mounted) setState(() {});
  }

  Future<void> _confirmRemoveQuestion(QuestionModel question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard(context),
          title: const Text(
            'Soruyu kaldır?',
            style: TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Bu soru yanlış defterinden silinir. İstersen testlerde '
            'tekrar yanlış yapınca yeniden eklenir.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.champagne,
                foregroundColor: AppTheme.ink,
              ),
              child: const Text(
                'Kaldır',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await ContentBankService.instance.removeWrongQuestion(question.id);
    if (!mounted) return;
    WrongNotebookRemoveToast.show(
      context,
      preview: QuestionStemContent.previewText(question.soruMetni),
    );
  }

  Future<void> _unlockGuestQuestion(
    BuildContext context,
    QuestionModel question,
  ) async {
    final ok = await AccountLinkCard.prompt(
      context,
      title: 'Giriş yap',
      subtitle: 'Soru metnini görmek için Google hesabını bağla.',
    );
    if (!ok || !mounted) return;
    // Aktarım auth içinde beklenir; emin olmak için bir kez daha senkronize et.
    await ContentBankService.instance.onUserSessionChanged();
    if (!mounted) return;
    await _openQuestion(this.context, question.id);
  }

  Future<void> _openQuestion(BuildContext context, String questionId) async {
    final bank = ContentBankService.instance;
    final question = bank.questionById(questionId);
    if (question == null) return;

    AdManager.instance.skipNextPageTransition();
    final storedAnswer = bank.wrongSelectionFor(question.id);
    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(
          title: question.konuAdi.isNotEmpty ? question.konuAdi : 'Yanlış soru',
          questions: [question],
          fromWrongNotebook: true,
          skipResultDialog: true,
          initialAnswers: storedAnswer != null ? [storedAnswer] : null,
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
          suppressWrongNotebookHint: true,
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

  Map<String, List<QuestionModel>> _groupBySubject(
      List<QuestionModel> questions) {
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
        ManualQuestionService.instance,
        FavoritesService.instance,
        PlayBillingService.instance.premiumNotifier,
        AuthService.instance,
      ]),
      builder: (context, _) {
        final bank = ContentBankService.instance;
        final favs = FavoritesService.instance;
        final manual = ManualQuestionService.instance.items;
        final kpssType = KpssPreferenceService.instance.kpssType;
        final guestLocked = !AuthService.instance.hasPermanentAccount;
        final allQuestions =
            bank.questionsByIds(bank.wrongQuestionIds.toList());
        final testWrongCount = allQuestions.length;
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
            centerTitle: false,
            titleSpacing: 0,
            leading: const AppBackButton(),
            title: const WrongNotebookHeaderTitleBlock(),
            actions: [
              if (allQuestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: WrongNotebookHeaderPill(
                      label: 'Akıllı Tekrar',
                      icon: Icons.psychology_alt_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                SmartReviewScreen(kpssType: kpssType),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(width: 8),
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
            child: allQuestions.isEmpty && manual.isEmpty
                ? (_hydrating
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppTheme.champagne,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WrongNotebookBookMistakesButton(
                            count: 0,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const WrongNotebookManualScreen(),
                                ),
                              );
                            },
                          ),
                          Expanded(
                            child: WrongNotebookEmptyState(kpssType: kpssType),
                          ),
                        ],
                      ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WrongNotebookStatsRow(
                        questionCount: testWrongCount,
                        subjectCount: subjects.length,
                        topSubject:
                            subjects.isNotEmpty ? subjects.first.$1 : null,
                        topSubjectCount:
                            subjects.isNotEmpty ? subjects.first.$2 : null,
                      ),
                      WrongNotebookBookMistakesButton(
                        count: manual.length,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const WrongNotebookManualScreen(),
                            ),
                          );
                        },
                      ),
                      if (allQuestions.isNotEmpty)
                        WrongNotebookSubjectFilter(
                          subjects: subjects,
                          totalCount: allQuestions.length,
                          selectedSubject: _subjectFilter,
                          onChanged: (value) =>
                              setState(() => _subjectFilter = value),
                        ),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            if (allQuestions.isEmpty) {
                              return ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      12,
                                      4,
                                      18,
                                    ),
                                    child: Text(
                                      'Test yanlışın yok. Kitap soruların için '
                                      'yukarıdaki pembe alana dokun.',
                                      style: TextStyle(
                                        color: AppTheme.slate
                                            .withValues(alpha: 0.68),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            if (questions.isEmpty) {
                              return ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      12,
                                      4,
                                      18,
                                    ),
                                    child: Text(
                                      'Bu derste yanlış soru yok.',
                                      style: TextStyle(
                                        color: AppTheme.slate
                                            .withValues(alpha: 0.68),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Header + kart satırlarını düzleştir — lazy build.
                            final rows =
                                <({bool isHeader, String? subject, int? count, QuestionModel? question})>[];
                            for (final entry in grouped.entries) {
                              rows.add((
                                isHeader: true,
                                subject: entry.key,
                                count: entry.value.length,
                                question: null,
                              ));
                              for (final q in entry.value) {
                                rows.add((
                                  isHeader: false,
                                  subject: null,
                                  count: null,
                                  question: q,
                                ));
                              }
                            }

                            return ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                if (row.isHeader) {
                                  return WrongNotebookSubjectHeader(
                                    subject: row.subject!,
                                    count: row.count!,
                                  );
                                }
                                final q = row.question!;
                                return WrongNotebookQuestionCard(
                                  question: q,
                                  isFavorite: favs.isFavorite(q.id),
                                  similarLoading:
                                      _similarLoadingId == q.id,
                                  showProBadge:
                                      !PremiumService.instance.isPremium,
                                  frostStem: guestLocked,
                                  onSignIn: () {
                                    unawaited(
                                      _unlockGuestQuestion(context, q),
                                    );
                                  },
                                  onToggleFavorite: () =>
                                      _toggleFavorite(q.id),
                                  onSimilar: () =>
                                      _openSimilar(context, q),
                                  onTap: () =>
                                      _openQuestion(context, q.id),
                                  onRemove: () =>
                                      _confirmRemoveQuestion(q),
                                );
                              },
                            );
                          },
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
