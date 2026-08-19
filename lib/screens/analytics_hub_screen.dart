import 'dart:async';

import 'package:flutter/material.dart';

import '../models/subject_performance.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../services/notes_service.dart';
import '../services/performance_summary_service.dart';
import '../services/question_fetch_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/account_link_card.dart';
import '../widgets/analytics_study_vault.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/scale_button.dart';
import 'study_hub_screen.dart';
import 'subject_analytics_detail_screen.dart';
import 'favorites_screen.dart';
import 'notes_screen.dart';
import 'wrong_questions_screen.dart';

/// Ders bazlı performans özeti (yalnızca konu testleri).
class AnalyticsHubScreen extends StatefulWidget {
  final KpssType kpssType;
  final bool embedded;

  const AnalyticsHubScreen({
    super.key,
    required this.kpssType,
    this.embedded = false,
  });

  @override
  State<AnalyticsHubScreen> createState() => _AnalyticsHubScreenState();
}

class _AnalyticsHubScreenState extends State<AnalyticsHubScreen> {
  @override
  void initState() {
    super.initState();
    FavoritesService.instance.initialize();
    unawaited(_hydrateWrongBodies());
  }

  Future<void> _hydrateWrongBodies() async {
    final bank = ContentBankService.instance;
    await bank.initialize();
    final missing = bank.unresolvedWrongQuestionIds;
    if (missing.isEmpty) return;
    await QuestionFetchService.instance.fetchByIds(missing);
    await bank.persistWrongQuestionBodiesNow();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ContentBankService.instance,
        FavoritesService.instance,
        NotesService.instance,
      ]),
      builder: (context, _) {
        final overall =
            PerformanceSummaryService.instance.overall(widget.kpssType);
        final subjects = PerformanceSummaryService.instance
            .subjectBreakdown(widget.kpssType);
        final wrongCount = ContentBankService.instance.wrongQuestionCount;
        final favCount = FavoritesService.instance.count;
        final notesCount = NotesService.instance.count;

        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: widget.embedded
              ? null
              : AppBar(
                  backgroundColor: AppTheme.page(context),
                  foregroundColor: AppTheme.onPage(context),
                  leading: const AppBackButton(),
                  title: const Text(
                    'Gelişim',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w600,
                    ),
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
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                widget.embedded ? 8 : 8,
                20,
                40,
              ),
              children: [
                _HeroSummary(overall: overall),
                const AccountLinkCard(
                  margin: EdgeInsets.only(top: 12),
                ),
                const SizedBox(height: 12),
                AnalyticsStudyVault(
                  wrongCount: wrongCount,
                  favoriteCount: favCount,
                  notesCount: notesCount,
                  onWrongTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WrongQuestionsScreen(),
                      ),
                    );
                  },
                  onFavoritesTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    );
                  },
                  onNotesTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NotesScreen(kpssType: widget.kpssType),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'DERSLER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.champagne.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Konu testlerine göre',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedOnPage(context),
                  ),
                ),
                const SizedBox(height: 14),
                _SubjectCarouselSection(
                  subjects: subjects,
                  kpssType: widget.kpssType,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubjectCarouselSection extends StatefulWidget {
  final List<SubjectPerformance> subjects;
  final KpssType kpssType;

  const _SubjectCarouselSection({
    required this.subjects,
    required this.kpssType,
  });

  @override
  State<_SubjectCarouselSection> createState() =>
      _SubjectCarouselSectionState();
}

class _SubjectCarouselSectionState extends State<_SubjectCarouselSection> {
  static const _cardWidth = 272.0;
  static const _gap = 10.0;

  late final ScrollController _scrollCtrl;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_syncActiveIndex);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_syncActiveIndex);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _syncActiveIndex() {
    if (!_scrollCtrl.hasClients || widget.subjects.isEmpty) return;
    const stride = _cardWidth + _gap;
    final next = (_scrollCtrl.offset / stride)
        .round()
        .clamp(0, widget.subjects.length - 1);
    if (next == _activeIndex) return;
    setState(() => _activeIndex = next);
  }

  void _jumpToIndex(int index) {
    if (!_scrollCtrl.hasClients) return;
    const stride = _cardWidth + _gap;
    _scrollCtrl.animateTo(
      index * stride,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: ListView.separated(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.subjects.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (context, index) {
              return SizedBox(
                width: _cardWidth,
                child: _SubjectCard(
                  performance: widget.subjects[index],
                  kpssType: widget.kpssType,
                  compact: true,
                ),
              );
            },
          ),
        ),
        if (widget.subjects.length > 1) ...[
          const SizedBox(height: 10),
          _SubjectScrollDots(
            count: widget.subjects.length,
            activeIndex: _activeIndex,
            onDotTap: _jumpToIndex,
          ),
        ],
      ],
    );
  }
}

class _SubjectScrollDots extends StatelessWidget {
  final int count;
  final int activeIndex;
  final ValueChanged<int> onDotTap;

  const _SubjectScrollDots({
    required this.count,
    required this.activeIndex,
    required this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onDotTap(i),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: i == activeIndex ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: i == activeIndex
                    ? AppTheme.champagne
                    : AppTheme.champagne.withValues(alpha: 0.22),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final OverallPerformance overall;

  const _HeroSummary({required this.overall});

  @override
  Widget build(BuildContext context) {
    final hasData = overall.solved > 0;
    final rate = (overall.successRate * 100).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.42),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF18263C),
                AppTheme.inkSoft,
                AppTheme.ink,
              ],
              stops: [0, 0.45, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.champagneLight,
                        AppTheme.champagne,
                        Color(0xFFB8924A),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -28,
                top: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.champagne.withValues(alpha: 0.18),
                          AppTheme.champagne.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: hasData
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BAŞARI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: AppTheme.champagne,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '%$rate',
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 44,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${overall.correct} doğru  ·  ${overall.wrong} yanlış'
                            '${overall.blank > 0 ? '  ·  ${overall.blank} boş' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: overall.successRate.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor:
                                  AppTheme.champagne.withValues(alpha: 0.16),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.champagne,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                '${overall.solved} çözülen',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${overall.totalQuestions} soruluk havuz',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.42),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BAŞARI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: AppTheme.champagne,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Henüz ölçüm yok',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 24,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Konu testlerini çözdükçe başarı oranın burada toplanır.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.5),
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
}

class _SubjectCard extends StatelessWidget {
  final SubjectPerformance performance;
  final KpssType kpssType;
  final bool compact;

  const _SubjectCard({
    required this.performance,
    required this.kpssType,
    this.compact = false,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubjectAnalyticsDetailScreen(
          kpssType: kpssType,
          subjectId: performance.subjectId,
          subjectName: performance.subjectName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = performance;
    final rate = (p.successRate * 100).round();
    final accent = SubjectNeonPalette.forSubject(p.subjectId);
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 10),
      child: ScaleButton(
        onPressed: () => _openDetail(context),
        child: Container(
          height: compact ? double.infinity : null,
          padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 12, compact ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppTheme.surfaceCard(context),
            border: Border.all(color: AppTheme.hairline(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      subjectIcon(p.subjectId),
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.subjectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w600,
                        color: on,
                      ),
                    ),
                  ),
                  Text(
                    p.hasActivity ? '%$rate' : '—',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: p.hasActivity
                          ? AppTheme.champagne
                          : muted.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: muted.withValues(alpha: 0.6),
                  ),
                ],
              ),
              if (!p.hasActivity) ...[
                const SizedBox(height: 10),
                Text(
                  'Henüz soru çözülmedi',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: p.successRate.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${p.solved} soru  ·  ${p.correct} doğru  ·  ${p.wrong} yanlış',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
