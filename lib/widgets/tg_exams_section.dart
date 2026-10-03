import 'dart:async';

import 'package:flutter/material.dart';

import '../models/tg_exam_models.dart';
import '../screens/tg_exam/exam_welcome_screen.dart';
import '../screens/tg_exam/tg_exam_instant_summary_screen.dart';
import '../screens/tg_exam/tg_exam_result_screen.dart';
import '../services/kpss_preference_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../services/tg_exam_service.dart';
import '../theme/app_theme.dart';
import 'exam_premium_shell.dart';
import 'exam_section_header.dart';
import 'tg_exam_gates.dart';

/// Deneme sekmesinde TG denemeleri — Aktif / Geçmiş bölümleri.
class TgExamsSection extends StatefulWidget {
  final VoidCallback? onRefresh;

  const TgExamsSection({super.key, this.onRefresh});

  @override
  State<TgExamsSection> createState() => _TgExamsSectionState();
}

class _TgExamsSectionState extends State<TgExamsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kpss = KpssPreferenceService.instance.kpssType;
      unawaited(TgExamService.instance.initialize(kpssType: kpss));
    });
    TgExamService.instance.addListener(_onService);
  }

  @override
  void dispose() {
    TgExamService.instance.removeListener(_onService);
    super.dispose();
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await TgExamService.instance.refresh();
    widget.onRefresh?.call();
  }

  List<TgExamModel> _activeExams(List<TgExamModel> exams) {
    return exams.where((e) => !e.isResultsPublished).toList();
  }

  List<TgExamModel> _pastExams(List<TgExamModel> exams) {
    return exams.where((e) => e.isResultsPublished).toList();
  }

  @override
  Widget build(BuildContext context) {
    final service = TgExamService.instance;
    final exams = service.exams;
    final active = _activeExams(exams);
    final past = _pastExams(exams);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExamSectionHeader(
          title: 'Türkiye Geneli Denemeler',
          subtitle: 'Resmî TG oturumları — aktif ve geçmiş denemeleriniz.',
          trailing: service.loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.champagne,
                  ),
                )
              : null,
        ),
        if (exams.isEmpty && !service.loading) ...[
          _EmptyTgState(
            error: service.lastError,
            onRetry: () => unawaited(_refresh()),
          ),
        ] else ...[
          if (active.isNotEmpty) ...[
            const _EyebrowLabel(title: 'Aktif Denemeler'),
            const SizedBox(height: 10),
            ...active.map(
              (exam) => _TgExamCard(exam: exam, showLiveBadge: true),
            ),
            const SizedBox(height: 18),
          ],
          if (past.isNotEmpty) ...[
            const _EyebrowLabel(title: 'Geçmiş Denemeler'),
            const SizedBox(height: 10),
            ...past.map(
              (exam) => _TgExamCard(exam: exam, showLiveBadge: false),
            ),
          ],
          if (active.isEmpty && past.isEmpty && !service.loading)
            Text(
              'Görüntülenecek deneme yok.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.mutedOnPage(context),
              ),
            ),
        ],
        if (exams.isNotEmpty) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: service.loading ? null : () => unawaited(_refresh()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yenile'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.champagne,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyTgState extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;

  const _EmptyTgState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ExamPremiumCardShell(
      accentBar: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.champagne.withValues(alpha: 0.12),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              error != null
                  ? Icons.cloud_off_outlined
                  : Icons.event_available_outlined,
              color: AppTheme.champagne,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            error != null
                ? 'TG denemeleri yüklenemedi'
                : 'Henüz Türkiye Geneli deneme yok',
            style: TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.onPage(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error ??
                'Yeni denemeler duyurulunca burada görünür.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Yeniden dene'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EyebrowLabel extends StatelessWidget {
  final String title;

  const _EyebrowLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: AppTheme.champagne.withValues(alpha: 0.95),
      ),
    );
  }
}

class _TgExamCard extends StatelessWidget {
  final TgExamModel exam;
  final bool showLiveBadge;

  const _TgExamCard({
    required this.exam,
    required this.showLiveBadge,
  });

  bool get _isLiveNow {
    final now = DateTime.now();
    return now.isAfter(exam.startAt) && now.isBefore(exam.endAt);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlayBillingService.instance.premiumNotifier,
      builder: (context, _, __) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final attempt = exam.myAttempt;
    final rank = attempt?.ranking;
    final participants = exam.participantCount;
    final isPremium = PremiumService.instance.isPremium;
    final showRank = exam.canAccessDetailedAnalysis &&
        isPremium &&
        rank != null &&
        participants > 0;
    final waitingResults = exam.isScoreCalculatedWaitingResults;
    final net = attempt?.net ?? 0;
    final showBadge = showLiveBadge && _isLiveNow && !exam.hasSubmittedAttempt;
    final canEnter = exam.canEnterLiveExam;
    final meta = _metaLine(exam, participants);
    final liveStyle = canEnter || showBadge;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: liveStyle
          ? _LiveExamShell(child: _cardBody(
              context,
              waitingResults: waitingResults,
              net: net,
              showBadge: showBadge,
              canEnter: canEnter,
              meta: meta,
              showRank: showRank,
              rank: rank,
              participants: participants,
              lightText: true,
            ))
          : ExamPremiumCardShell(
              child: _cardBody(
                context,
                waitingResults: waitingResults,
                net: net,
                showBadge: showBadge,
                canEnter: canEnter,
                meta: meta,
                showRank: showRank,
                rank: rank,
                participants: participants,
                lightText: false,
              ),
            ),
    );
  }

  Widget _cardBody(
    BuildContext context, {
    required bool waitingResults,
    required double net,
    required bool showBadge,
    required bool canEnter,
    required String meta,
    required bool showRank,
    required int? rank,
    required int participants,
    required bool lightText,
  }) {
    final titleColor = lightText ? Colors.white : AppTheme.onPage(context);
    final muted = lightText
        ? Colors.white.withValues(alpha: 0.62)
        : AppTheme.mutedOnPage(context);
    final accent = lightText ? AppTheme.champagneLight : AppTheme.champagne;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusMark(
              waitingResults: waitingResults,
              net: net,
              percent: exam.displaySuccessPercent,
              light: lightText,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          exam.title,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.2,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (showBadge) ...[
                        const SizedBox(width: 8),
                        const _LiveBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusLabel(exam),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: waitingResults
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: waitingResults ? accent : muted,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: meta
                          .split(' · ')
                          .map((p) => _MetaChip(label: p, light: lightText))
                          .toList(),
                    ),
                  ],
                  if (showRank) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$participants kişi içinde $rank. oldun',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (waitingResults) ...[
          const SizedBox(height: 16),
          _SecondaryAction(
            label: 'Puan Özetini Gör',
            onPressed: () => _openSummary(context),
            light: lightText,
          ),
        ] else if (exam.canAccessDetailedAnalysis) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SecondaryAction(
                  label: 'Çözümleri İncele',
                  icon: Icons.menu_book_outlined,
                  onPressed: exam.canAccessSolutions
                      ? () => _openSolutions(context)
                      : null,
                  light: lightText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PrimaryAction(
                  label: 'Detaylı Analiz',
                  icon: Icons.analytics_outlined,
                  onPressed: () => _openAnalysis(context),
                ),
              ),
            ],
          ),
        ] else if (canEnter) ...[
          const SizedBox(height: 16),
          _PrimaryAction(
            label: exam.hasOpenAttempt ? 'Denemeye Devam Et' : 'Denemeye Başla',
            icon: Icons.play_arrow_rounded,
            onPressed: () => _openWelcome(context),
          ),
        ] else if (!exam.hasSubmittedAttempt) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openWelcome(context),
              style: TextButton.styleFrom(
                foregroundColor: accent,
              ),
              child: const Text('Denemeye git'),
            ),
          ),
        ],
      ],
    );
  }

  String _metaLine(TgExamModel exam, int participants) {
    final parts = <String>[];
    final kpss = exam.kpssType.trim();
    if (kpss.isNotEmpty) parts.add(kpss);
    if (participants > 0) parts.add('$participants katılımcı');
    parts.add('${exam.questionCount} soru');
    parts.add('${exam.durationMinutes} dk');
    return parts.join(' · ');
  }

  String _statusLabel(TgExamModel exam) {
    if (exam.isScoreCalculatedWaitingResults) {
      if (exam.isAwaitingResultsPublication) {
        return 'Sınavı tamamladın — sonuçlar hesaplanıyor';
      }
      return 'Sınavı tamamladın — puanın hesaplandı';
    }
    switch (exam.status) {
      case TgExamStatus.notStarted:
        return 'Yakında başlayacak';
      case TgExamStatus.active:
        return 'Aktif — katılabilirsin';
      case TgExamStatus.inProgress:
        return 'Devam ediyor';
      case TgExamStatus.submittedWaiting:
        return 'Gönderildi — sonuç bekleniyor';
      case TgExamStatus.ended:
        return 'Süre doldu — sonuçlar bekleniyor';
      case TgExamStatus.results:
        return 'Sonuçlar açık';
    }
  }

  Future<void> _openWelcome(BuildContext context) async {
    if (!await TgExamGates.requireGoogleAccount(context)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamWelcomeScreen(examId: exam.id),
      ),
    );
  }

  void _openSummary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TgExamInstantSummaryScreen(exam: exam),
      ),
    );
  }

  Future<void> _openAnalysis(BuildContext context) async {
    await TgExamGates.openDetailedAnalysis(context, exam);
  }

  void _openSolutions(BuildContext context) {
    unawaited(TgExamResultScreen.openSolutionsReview(context, exam));
  }
}

class _LiveExamShell extends StatelessWidget {
  final Widget child;

  const _LiveExamShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A2438),
                      Color(0xFF141C2E),
                      Color(0xFF0C1424),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.champagne.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 2.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6B0F1A),
                      AppTheme.champagne,
                      Color(0xFFFFE7B8),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMark extends StatelessWidget {
  final bool waitingResults;
  final double net;
  final double percent;
  final bool light;

  const _StatusMark({
    required this.waitingResults,
    required this.net,
    required this.percent,
    required this.light,
  });

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0);
    final track = light
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.hairline(context);
    final label = waitingResults
        ? net.toStringAsFixed(1)
        : (percent > 0 ? '%${percent.round()}' : '—');

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: light
            ? Colors.white.withValues(alpha: 0.06)
            : AppTheme.champagne.withValues(alpha: 0.08),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: light ? 0.45 : 0.3),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: waitingResults ? null : (value > 0 ? value : 0),
              strokeWidth: 3.5,
              backgroundColor: track,
              color: AppTheme.champagneLight,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: waitingResults ? 11 : 10,
              fontWeight: FontWeight.w700,
              color: light ? Colors.white : AppTheme.onPage(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final bool light;

  const _MetaChip({required this.label, required this.light});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: light
            ? Colors.white.withValues(alpha: 0.08)
            : AppTheme.champagne.withValues(alpha: 0.1),
        border: Border.all(
          color: light
              ? Colors.white.withValues(alpha: 0.14)
              : AppTheme.champagne.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: light
              ? Colors.white.withValues(alpha: 0.82)
              : AppTheme.mutedOnPage(context),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.champagne.withValues(alpha: 0.28),
            AppTheme.champagne.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.champagneLight.withValues(alpha: 0.65),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: Color(0xFF34D399)),
          SizedBox(width: 5),
          Text(
            'YAYINDA',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppTheme.champagneLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFE2C998),
                Color(0xFFC9A86C),
                Color(0xFFB8944A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: AppTheme.ink),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
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

class _SecondaryAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool light;

  const _SecondaryAction({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.light,
  });

  @override
  Widget build(BuildContext context) {
    final border = light
        ? Colors.white.withValues(alpha: 0.22)
        : AppTheme.champagne.withValues(alpha: 0.4);
    final fg = light ? Colors.white : AppTheme.champagne;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 17) : const SizedBox.shrink(),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
