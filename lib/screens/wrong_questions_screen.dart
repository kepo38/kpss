import 'package:flutter/material.dart';

import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../services/ad_manager.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/question_stem_content.dart';
import '../widgets/study_empty_cta.dart';
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

  @override
  void initState() {
    super.initState();
    FavoritesService.instance.initialize();
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
      ]),
      builder: (context, _) {
        final bank = ContentBankService.instance;
        final favs = FavoritesService.instance;
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
            leading: const AppBackButton(),
            title: const Text(
              'Yanlış Defteri',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (allQuestions.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SmartReviewScreen(
                          kpssType: KpssType.lisans,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Akıllı',
                    style: TextStyle(
                      color: AppTheme.neonEdge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (questions.isNotEmpty)
                TextButton(
                  onPressed: () => _practiceAll(questions),
                  child: const Text(
                    'Çöz',
                    style: TextStyle(
                      color: AppTheme.champagne,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                ? const StudyEmptyCta(
                    icon: Icons.note_alt_outlined,
                    title: 'Henüz yanlış soru yok',
                    message:
                        'Konu testlerini bitirdiğinizde yanlış yaptığınız '
                        'sorular burada toplanır. Testten erken çıkarsanız '
                        'kaydedilmez.',
                    kpssType: KpssType.lisans,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          '${allQuestions.length} soru · '
                          '${subjects.length} ders',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      if (subjects.length > 1) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              FilterChip(
                                label: Text('Tümü (${allQuestions.length})'),
                                selected: _subjectFilter == null,
                                onSelected: (_) =>
                                    setState(() => _subjectFilter = null),
                                selectedColor:
                                    AppTheme.champagne.withValues(alpha: 0.35),
                                checkmarkColor: AppTheme.ink,
                              ),
                              const SizedBox(width: 8),
                              ...subjects.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text('${s.$1} (${s.$2})'),
                                    selected: _subjectFilter == s.$1,
                                    onSelected: (_) => setState(
                                      () => _subjectFilter =
                                          _subjectFilter == s.$1 ? null : s.$1,
                                    ),
                                    selectedColor: AppTheme.champagne
                                        .withValues(alpha: 0.35),
                                    checkmarkColor: AppTheme.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                                    const EdgeInsets.fromLTRB(20, 12, 20, 40),
                                children: [
                                  for (final entry in grouped.entries) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 6,
                                      ),
                                      child: Text(
                                        '${entry.key} (${entry.value.length})',
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.onPage(context),
                                        ),
                                      ),
                                    ),
                                    for (var i = 0; i < entry.value.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          color: AppTheme.ink
                                              .withValues(alpha: 0.08),
                                        ),
                                      _WrongQuestionTile(
                                        question: entry.value[i],
                                        isFavorite: favs.isFavorite(
                                          entry.value[i].id,
                                        ),
                                        onToggleFavorite: () =>
                                            _toggleFavorite(entry.value[i].id),
                                        onTap: () => _openQuestion(
                                          context,
                                          entry.value[i].id,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _WrongQuestionTile extends StatelessWidget {
  final QuestionModel question;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _WrongQuestionTile({
    required this.question,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        QuestionStemContent.previewText(question.soruMetni),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.ink,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        question.konuAdi,
        style: TextStyle(
          color: AppTheme.slate.withValues(alpha: 0.65),
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        tooltip: isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
        onPressed: onToggleFavorite,
        icon: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite
              ? AppTheme.champagne
              : AppTheme.slate.withValues(alpha: 0.45),
          size: 22,
        ),
      ),
      onTap: onTap,
    );
  }
}
