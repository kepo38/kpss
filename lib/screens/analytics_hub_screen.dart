import 'dart:async';

import 'package:flutter/material.dart';

import '../models/subject_performance.dart';
import '../services/content_bank_service.dart';
import '../services/favorites_service.dart';
import '../services/notes_service.dart';
import '../services/performance_summary_service.dart';
import '../services/question_fetch_service.dart';
import '../services/ai_coach_service.dart';
import '../services/weekly_study_plan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_coach_insight_card.dart';
import '../widgets/weekly_study_plan_card.dart';
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
import 'topic_detail_screen.dart';
import 'wrong_questions_screen.dart';

/// Ders bazlı performans özeti (yalnızca konu testleri).
class AnalyticsHubScreen extends StatefulWidget {
  final KpssType kpssType;
  final bool embedded;
  final bool isPremium;

  const AnalyticsHubScreen({
    super.key,
    required this.kpssType,
    this.embedded = false,
    this.isPremium = false,
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
        final coachInsight =
            AiCoachService.instance.buildTopicTestInsight(widget.kpssType) ??
            AiCoachService.instance.buildExamTrendInsight(widget.kpssType);
        final weeklyPlan =
            WeeklyStudyPlanService.instance.buildPlan(widget.kpssType);

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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                widget.embedded ? 8 : 8,
                20,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroSummary(overall: overall),
                  const SizedBox(height: 20),
                  const AccountLinkCard(),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  WeeklyStudyPlanCard(
                    days: weeklyPlan,
                    isPremium: widget.isPremium,
                  ),
                  const SizedBox(height: 28),
                  const _SectionHeader(
                    title: 'DERSLER',
                    subtitle: 'Konu testlerine göre',
                  ),
                  const SizedBox(height: 14),
                  _SubjectCarouselSection(
                    subjects: subjects,
                    kpssType: widget.kpssType,
                  ),
                  const SizedBox(height: 20),
                  AiCoachInsightCard(
                    insight: coachInsight,
                    isPremium: widget.isPremium,
                    onTopicTap:
                        widget.isPremium && coachInsight?.canOpenTopic == true
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TopicDetailScreen(
                                  kpssType: coachInsight!.kpssType!,
                                  subjectId: coachInsight.subjectId!,
                                  topicId: coachInsight.topicId!,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
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
  static const _gap = 10.0;
  /// Sonraki karttan ekranda kalan peep (kaydırılabilir ipucu).
  static const _peek = 56.0;

  late final ScrollController _scrollCtrl;
  int _activeIndex = 0;
  bool _canScrollMore = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFade();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    _syncActiveIndex();
    _syncFade();
  }

  void _syncFade() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final more = max > 4 && _scrollCtrl.offset < max - 4;
    if (more == _canScrollMore) return;
    setState(() => _canScrollMore = more);
  }

  void _syncActiveIndex() {
    if (!_scrollCtrl.hasClients || widget.subjects.isEmpty) return;
    final cardWidth = _cardWidth(context);
    final stride = cardWidth + _gap;
    final next = (_scrollCtrl.offset / stride)
        .round()
        .clamp(0, widget.subjects.length - 1);
    if (next == _activeIndex) return;
    setState(() => _activeIndex = next);
  }

  double _cardWidth(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).width - 40; // ListView pad
    return (viewport - _peek).clamp(220.0, 300.0);
  }

  void _jumpToIndex(int index) {
    if (!_scrollCtrl.hasClients) return;
    final stride = _cardWidth(context) + _gap;
    _scrollCtrl.animateTo(
      index * stride,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = _cardWidth(context);
    // Fade rengi sayfa zeminiyle uyumlu
    final fadeEdge = AppTheme.page(context);

    return Column(
      children: [
        SizedBox(
          height: 176,
          child: Stack(
            children: [
              ListView.separated(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.subjects.length,
                separatorBuilder: (_, __) => const SizedBox(width: _gap),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: cardWidth,
                    child: _SubjectCard(
                      performance: widget.subjects[index],
                      kpssType: widget.kpssType,
                      compact: true,
                    ),
                  );
                },
              ),
              if (_canScrollMore)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 40,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            fadeEdge.withValues(alpha: 0),
                            fadeEdge.withValues(alpha: 0.72),
                            fadeEdge,
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.champagne.withValues(alpha: 0.98),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedOnPage(context),
                ),
              ),
            ],
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
    final netPct = (overall.netAccuracy * 100).round();
    final rawPct = (overall.successRate * 100).round();
    final netLabel = overall.net.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A283C),
            Color(0xFF0C1424),
            Color(0xFF0A101C),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'NET',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.champagne.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  netLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                    color: AppTheme.champagneLight,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Net oranı %$netPct',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.neonEdge.withValues(alpha: 0.95),
                  ),
                ),
                if (rawPct != netPct) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ham %$rawPct',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroMetric(
                          label: 'Doğru',
                          value: '${overall.correct}',
                          color: const Color(0xFF4ADE80),
                        ),
                      ),
                      _HeroMetricDivider(),
                      Expanded(
                        child: _HeroMetric(
                          label: 'Yanlış',
                          value: '${overall.wrong}',
                          color: const Color(0xFFF87171),
                        ),
                      ),
                      _HeroMetricDivider(),
                      Expanded(
                        child: _HeroMetric(
                          label: 'Boş',
                          value: '${overall.blank}',
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${overall.solved} çözülen',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${overall.totalQuestions} soruluk havuz',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                Text(
                  'NET',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3.2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.champagne.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Henüz ölçüm yok',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Konu testlerini çözdükçe net oranın burada toplanır.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeroMetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
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
          padding: EdgeInsets.fromLTRB(
            14,
            compact ? 14 : 14,
            12,
            compact ? 14 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: AppTheme.surfaceCard(context),
            border: Border.all(
              color: accent.withValues(alpha: p.hasActivity ? 0.22 : 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: p.hasActivity ? 0.1 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.18),
                          accent.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Icon(
                      subjectIcon(p.subjectId),
                      size: 19,
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
                        fontWeight: FontWeight.w700,
                        color: on,
                      ),
                    ),
                  ),
                  if (p.hasActivity)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.champagne.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '%$rate',
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.champagne,
                        ),
                      ),
                    )
                  else
                    Text(
                      '—',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: muted.withValues(alpha: 0.5),
                      ),
                    ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: muted.withValues(alpha: 0.55),
                  ),
                ],
              ),
              if (!p.hasActivity) ...[
                const SizedBox(height: 12),
                Text(
                  'Henüz soru çözülmedi',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ] else ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: p.successRate.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: accent.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${p.solved} soru  ·  ${p.correct} doğru  ·  ${p.wrong} yanlış',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
