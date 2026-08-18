import 'package:flutter/material.dart';

import '../models/question_model.dart';
import '../services/ad_manager.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/question_stem_content.dart';
import '../widgets/study_empty_cta.dart';
import 'quiz_screen.dart';

/// Favori sorular listesi — güncel teste göre açılır.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    FavoritesService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  Map<String, List<QuestionModel>> _groupBySubject(List<QuestionModel> questions) {
    final grouped = <String, List<QuestionModel>>{};
    for (final q in questions) {
      grouped.putIfAbsent(q.dersAdi, () => []).add(q);
    }
    final keys = grouped.keys.toList()..sort();
    return {for (final k in keys) k: grouped[k]!};
  }

  Future<void> _openFavorite(String questionId) async {
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
      title = 'Favori soru';
    }

    AdManager.instance.skipNextPageTransition();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          title: title,
          questions: questions,
          timeLimitMinutes: timeLimit,
          initialIndex: initialIndex,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritesService.instance,
      builder: (context, _) {
        final ids = FavoritesService.instance.ids.toList();
        final bank = ContentBankService.instance;
        final questions = bank.questionsByIds(ids);
        final grouped = _groupBySubject(questions);

        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: AppBar(
            backgroundColor: AppTheme.page(context),
            foregroundColor: AppTheme.onPage(context),
            leading: const AppBackButton(),
            title: const Text(
              'Favorilerim',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (questions.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    AdManager.instance.skipNextPageTransition();
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => QuizScreen(
                          title: 'Favori Pratik',
                          questions: questions,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
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
            child: questions.isEmpty
                ? const StudyEmptyCta(
                    icon: Icons.favorite_border,
                    title: 'Henüz favori soru yok',
                    message:
                        'Test çözerken kalp ikonuna dokunun. '
                        'Önce bir dersten test çözerek başlayabilirsiniz.',
                    kpssType: KpssType.lisans,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6),
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
                            Divider(color: AppTheme.ink.withValues(alpha: 0.08)),
                          _FavoriteTile(
                            question: entry.value[i],
                            bank: bank,
                            onOpen: () => _openFavorite(entry.value[i].id),
                            onRemove: () async {
                              await FavoritesService.instance
                                  .remove(entry.value[i].id);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final QuestionModel question;
  final ContentBankService bank;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _FavoriteTile({
    required this.question,
    required this.bank,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final test = bank.testContainingQuestion(question.id);
    final testLabel = test?.title ?? 'Testte değil';
    final isFromWrong = bank.wrongQuestionIds.contains(question.id);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      title: Text(
        QuestionStemContent.previewText(question.soruMetni),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.ink,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${question.konuAdi} · $testLabel',
            style: TextStyle(
              color: AppTheme.slate.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          if (isFromWrong) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 12,
                  color: const Color(0xFFF87171).withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
                Text(
                  'Yanlış Defterinden eklendi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFFF87171).withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(
          Icons.favorite,
          color: AppTheme.champagne,
        ),
        onPressed: onRemove,
      ),
    );
  }
}
