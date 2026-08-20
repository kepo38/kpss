import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../models/question_model.dart';
import '../services/ad_manager.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../services/summary_card_progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/question_stem_content.dart';
import '../widgets/study_empty_cta.dart';
import '../widgets/topic_summary_swipe_deck.dart';
import 'quiz_screen.dart';

/// Favori sorular + özet konu kartları.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  /// Özet kartlar: favorites | weak
  String _cardFilter = 'favorites';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    FavoritesService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
    SummaryCardProgressService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Map<String, List<QuestionModel>> _groupBySubject(
    List<QuestionModel> questions,
  ) {
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

  Future<void> _openSummaryCard(TopicSummaryCardModel card) async {
    await SummaryCardFace.showViewer(context, card);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        FavoritesService.instance,
        SummaryCardProgressService.instance,
        ContentBankService.instance,
      ]),
      builder: (context, _) {
        final ids = FavoritesService.instance.ids.toList();
        final bank = ContentBankService.instance;
        final questions = bank.questionsByIds(ids);
        final grouped = _groupBySubject(questions);
        final progress = SummaryCardProgressService.instance;
        final cardIds = _cardFilter == 'weak'
            ? progress.weakIds
            : progress.favoriteIds;
        final cards = bank.summaryCardsByIds(cardIds);

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
              if (_tabs.index == 0 && questions.isNotEmpty)
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
            bottom: TabBar(
              controller: _tabs,
              onTap: (_) => setState(() {}),
              labelColor: AppTheme.champagne,
              unselectedLabelColor: AppTheme.mutedOnPage(context),
              indicatorColor: AppTheme.champagne,
              tabs: [
                Tab(text: 'Soru Favorileri (${questions.length})'),
                Tab(
                  text:
                      'Özet Kartlar (${progress.favoriteCount + progress.weakCount})',
                ),
              ],
            ),
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
            child: TabBarView(
              controller: _tabs,
              children: [
                questions.isEmpty
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
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 6),
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
                                  color:
                                      AppTheme.ink.withValues(alpha: 0.08),
                                ),
                              _FavoriteTile(
                                question: entry.value[i],
                                bank: bank,
                                onOpen: () =>
                                    _openFavorite(entry.value[i].id),
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
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Favoriler',
                            count: progress.favoriteCount,
                            selected: _cardFilter == 'favorites',
                            onTap: () =>
                                setState(() => _cardFilter = 'favorites'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Tekrar Et',
                            count: progress.weakCount,
                            selected: _cardFilter == 'weak',
                            onTap: () =>
                                setState(() => _cardFilter = 'weak'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: cards.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Text(
                                  _cardFilter == 'weak'
                                      ? 'Unuttuğun özet kart yok.\nKonu detayında sola kaydırınca buraya düşer.'
                                      : 'Favori özet kart yok.\nKart üzerindeki kalbe dokununca burada toplanır.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.mutedOnPage(context),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 28),
                              itemCount: cards.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final card = cards[index];
                                return _SummaryFavoriteTile(
                                  card: card,
                                  isWeak: progress.isWeak(card.id),
                                  onOpen: () => _openSummaryCard(card),
                                  onRemove: () async {
                                    if (_cardFilter == 'weak') {
                                      await progress.removeWeak(card.id);
                                    } else {
                                      await progress.removeFavorite(card.id);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: selected
              ? AppTheme.champagne.withValues(alpha: 0.18)
              : AppTheme.surfaceCard(context),
          border: Border.all(
            color: selected
                ? AppTheme.champagne.withValues(alpha: 0.55)
                : AppTheme.hairline(context),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.onPage(context),
          ),
        ),
      ),
    );
  }
}

class _SummaryFavoriteTile extends StatelessWidget {
  final TopicSummaryCardModel card;
  final bool isWeak;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _SummaryFavoriteTile({
    required this.card,
    required this.isWeak,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.surfaceCard(context),
        border: Border.all(color: AppTheme.hairline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        card.kindLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.champagne,
                        ),
                      ),
                      if (isWeak) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Tekrar Et',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                const Color(0xFFF87171).withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.title,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onPage(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppTheme.mutedOnPage(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${card.subjectName} · ${card.topicName}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.mutedOnPage(context)
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Kaldır',
            onPressed: onRemove,
            icon: Icon(
              isWeak ? Icons.close_rounded : Icons.favorite,
              color: isWeak
                  ? AppTheme.mutedOnPage(context)
                  : AppTheme.champagne,
            ),
          ),
        ],
      ),
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
        style: TextStyle(
          color: AppTheme.onPage(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${question.konuAdi} · $testLabel',
            style: TextStyle(
              color: AppTheme.mutedOnPage(context),
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
