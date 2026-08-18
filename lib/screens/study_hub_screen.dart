import 'package:flutter/material.dart';

import '../data/kpss_curriculum.dart';
import '../services/content_bank_service.dart';
import '../services/content_sync_service.dart';
import '../services/kpss_preference_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/app_back_button.dart';
import '../widgets/brand_mark.dart';
import '../widgets/continue_study_card.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/daily_mission_center.dart';
import '../widgets/daily_mini_exam_card.dart';
import '../widgets/exam_focus_panel.dart';
import '../widgets/exam_pack_showcase.dart';
import '../widgets/premium_header_button.dart';
import '../widgets/savings_insight_banner.dart';
import 'topic_detail_screen.dart';

IconData subjectIcon(String subjectId) {
  return switch (subjectId) {
    'turkce' => Icons.menu_book_rounded,
    'matematik' => Icons.functions_rounded,
    'tarih' => Icons.account_balance_rounded,
    'cografya' => Icons.public_rounded,
    'vatandaslik' => Icons.balance,
    'guncel' => Icons.feed_rounded,
    _ => Icons.school_rounded,
  };
}

/// Ders kutuları mı, ana sayfa akışı mı.
enum StudyHubPane { home, subjects }

/// Ders → konu seçimi (Soru sekmesi / müfredat).
class StudyHubScreen extends StatelessWidget {
  final KpssType kpssType;
  final bool embedded;
  final StudyHubPane pane;
  final ValueNotifier<KpssType>? selectedType;
  final ValueNotifier<bool>? isPremium;
  final VoidCallback? onPremiumTap;
  final VoidCallback? onMoreTap;
  final bool shellTopBarVisible;
  final ValueChanged<KpssType>? onKpssTypeChanged;

  const StudyHubScreen({
    super.key,
    required this.kpssType,
    this.embedded = false,
    this.pane = StudyHubPane.subjects,
    this.selectedType,
    this.isPremium,
    this.onPremiumTap,
    this.onMoreTap,
    this.shellTopBarVisible = false,
    this.onKpssTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return ListenableBuilder(
      listenable: ContentBankService.instance,
      builder: (context, _) {
        final subjects = KpssCurriculum.subjectsFor(kpssType);
        final bank = ContentBankService.instance;
        final showHome = embedded && pane == StudyHubPane.home;
        final showSubjects = pane == StudyHubPane.subjects;

        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: embedded
              ? null
              : AppBar(
                  backgroundColor: AppTheme.page(context),
                  foregroundColor: AppTheme.onPage(context),
                  leading: const AppBackButton(),
                  title: Text(
                    'TÜM DERSLER',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: AppTheme.onPage(context),
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
                  AppTheme.pageDeep(context),
                  AppTheme.page(context),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: RefreshIndicator(
              color: AppTheme.champagne,
              backgroundColor: AppTheme.surfaceCard(context),
              onRefresh: () =>
                  ContentSyncService.instance.syncCatalog(force: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (showHome)
                    SliverToBoxAdapter(
                      child: _SoruHeader(
                        topPad: topPad,
                        selectedType: selectedType!,
                        isPremium: isPremium!,
                        onPremiumTap: onPremiumTap,
                        onMoreTap: onMoreTap,
                        hideBrandRow: shellTopBarVisible,
                        onKpssTypeChanged: onKpssTypeChanged,
                      ),
                    ),
                  if (showSubjects) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _SubjectsHeader(
                          totalQuestions: subjects.fold<int>(
                            0,
                            (sum, s) =>
                                sum +
                                bank.catalogQuestionCountForSubject(
                                  kpssType,
                                  s.id,
                                ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        embedded ? 8 : 12,
                        16,
                        0,
                      ),
                      sliver: const SliverToBoxAdapter(
                        child: ContinueStudyCard(),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final subject = subjects[index];
                            final progress = bank.subjectQuestionProgress(
                              kpssType,
                              subject.id,
                            );
                            return _SubjectTile(
                              subjectId: subject.id,
                              name: subject.name,
                              icon: subjectIcon(subject.id),
                              subtitle:
                                  '${subject.topics.length} konu · ${progress.total} soru',
                              progress: progress.total == 0
                                  ? 0
                                  : progress.solved / progress.total,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SubjectTopicsScreen(
                                      kpssType: kpssType,
                                      subject: subject,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: subjects.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ExamPackShowcase(
                        examTypeId: KpssPreferenceService.instance.examTrackId,
                      ),
                    ),
                  ],
                  if (showHome)
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bir dersin konuları.
class SubjectTopicsScreen extends StatelessWidget {
  final KpssType kpssType;
  final KpssSubject subject;

  const SubjectTopicsScreen({
    super.key,
    required this.kpssType,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ContentBankService.instance,
      builder: (context, _) {
        final bank = ContentBankService.instance;

        return Scaffold(
          backgroundColor: AppTheme.page(context),
          appBar: AppBar(
            backgroundColor: AppTheme.page(context),
            foregroundColor: AppTheme.onPage(context),
            leading: const AppBackButton(),
            title: Row(
              children: [
                Icon(
                  subjectIcon(subject.id),
                  color: SubjectNeonPalette.forSubject(subject.id),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subject.name,
                    style: TextStyle(
                      color: AppTheme.onPage(context),
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: subject.topics.length,
            itemBuilder: (context, index) {
              final topic = subject.topics[index];
              final stats = bank.topicStats(topic.id);
              final tests = bank.testsForTopic(kpssType, topic.id);
              final questionCount =
                  bank.catalogQuestionCountForTopic(kpssType, topic.id);
              return _TopicTile(
                title: topic.name,
                subtitle:
                    '${tests.length} test · $questionCount soru'
                    '${stats.attemptCount > 0 ? ' · %${(stats.averageAccuracy * 100).round()} başarı' : ''}',
                accentNeon: SubjectNeonPalette.forSubject(subject.id),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TopicDetailScreen(
                        kpssType: kpssType,
                        subjectId: subject.id,
                        topicId: topic.id,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SubjectsHeader extends StatelessWidget {
  final int totalQuestions;

  const _SubjectsHeader({required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    final countLabel =
        totalQuestions == 0 ? 'Henüz soru yok' : '$totalQuestions soru';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Dersler',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.onPage(context),
                height: 1.1,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                countLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.champagne.withValues(alpha: 0.95),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String subjectId;
  final String name;
  final IconData icon;
  final String subtitle;
  final double progress;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.subjectId,
    required this.name,
    required this.icon,
    required this.subtitle,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final neon = SubjectNeonPalette.forSubject(subjectId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: neon.withValues(alpha: 0.12),
        highlightColor: neon.withValues(alpha: 0.06),
        child: Ink(
          decoration: SubjectNeonPalette.darkGlassCard(neon: neon, radius: 14),
          child: Stack(
            children: [
              Positioned(
                top: -12,
                right: -6,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        neon.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            neon.withValues(alpha: 0.28),
                            neon.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(color: neon.withValues(alpha: 0.65)),
                        boxShadow: SubjectNeonPalette.glow(neon, blur: 6),
                      ),
                      child: Icon(icon, size: 20, color: neon),
                    ),
                    const Spacer(),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: neon.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: neon.withValues(alpha: 0.16),
                        valueColor: AlwaysStoppedAnimation<Color>(neon),
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

class _SoruHeader extends StatelessWidget {
  final double topPad;
  final ValueNotifier<KpssType> selectedType;
  final ValueNotifier<bool> isPremium;
  final VoidCallback? onPremiumTap;
  final VoidCallback? onMoreTap;
  final bool hideBrandRow;
  final ValueChanged<KpssType>? onKpssTypeChanged;

  const _SoruHeader({
    required this.topPad,
    required this.selectedType,
    required this.isPremium,
    this.onPremiumTap,
    this.onMoreTap,
    this.hideBrandRow = false,
    this.onKpssTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        hideBrandRow ? 0 : topPad + 8,
        12,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideBrandRow) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onMoreTap,
                    behavior: HitTestBehavior.opaque,
                    child: const Tooltip(
                      message: 'Ana sayfa',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark.topBar(),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: isPremium,
                  builder: (context, premium, _) {
                    return _HeaderChip(
                      isPremium: premium,
                      onPremiumTap: premium ? null : onPremiumTap,
                      onMoreTap: onMoreTap,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ValueListenableBuilder<KpssType>(
            valueListenable: selectedType,
            builder: (context, type, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ExamFocusPanel(
                    light: true,
                  ),
                  DailyMiniExamCard(kpssType: type),
                  const SizedBox(height: 10),
                  DailyMissionCenter(
                    kpssType: type,
                    onSubjectTap: (subject) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SubjectTopicsScreen(
                            kpssType: type,
                            subject: subject,
                          ),
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: isPremium,
                    builder: (context, premium, _) {
                      return SavingsInsightBanner(
                        isPremium: premium,
                        onPremiumTap: onPremiumTap,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final bool isPremium;
  final VoidCallback? onPremiumTap;
  final VoidCallback? onMoreTap;

  const _HeaderChip({
    required this.isPremium,
    this.onPremiumTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PremiumHeaderButton(
          isPremium: isPremium,
          onTap: onPremiumTap,
        ),
        IconButton(
          tooltip: 'Daha fazla',
          onPressed: onMoreTap,
          icon: Icon(
            Icons.apps_outlined,
            color: AppTheme.mutedOnPage(context),
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentNeon;

  const _TopicTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentNeon,
  });

  @override
  Widget build(BuildContext context) {
    final neon = accentNeon ?? AppTheme.neonEdge;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: neon.withValues(alpha: 0.08),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.isDark(context)
                ? AppTheme.inkSoft.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.55),
            border: Border.all(color: AppTheme.hairline(context)),
            boxShadow: [
              BoxShadow(
                color: neon.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      neon,
                      neon.withValues(alpha: 0.35),
                    ],
                  ),
                  boxShadow: SubjectNeonPalette.glow(neon, blur: 4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onPage(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'sans-serif',
                        fontSize: 13,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: neon.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
