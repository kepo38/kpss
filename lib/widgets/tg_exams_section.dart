import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/tg_exam_models.dart';
import '../screens/tg_exam/exam_welcome_screen.dart';
import '../screens/tg_exam/tg_exam_instant_summary_screen.dart';
import '../screens/tg_exam/tg_exam_result_screen.dart';
import '../services/kpss_preference_service.dart';
import '../services/tg_exam_service.dart';
import '../theme/app_theme.dart';

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
        Row(
          children: [
            Expanded(
              child: Text(
                'TG Denemelerim',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onPage(context),
                ),
              ),
            ),
            if (service.loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (exams.isEmpty && !service.loading)
          Text(
            service.lastError ??
                'Henüz Türkiye Geneli deneme yok. Yeni denemeler duyurulunca burada görünür.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.mutedOnPage(context),
            ),
          )
        else ...[
          if (active.isNotEmpty) ...[
            const _SectionHeader(title: 'Aktif Denemeler'),
            const SizedBox(height: 8),
            ...active.map(
              (exam) => _TgExamCard(exam: exam, showLiveBadge: true),
            ),
            const SizedBox(height: 16),
          ],
          if (past.isNotEmpty) ...[
            const _SectionHeader(title: 'Geçmiş Denemeler'),
            const SizedBox(height: 8),
            ...past.map(
              (exam) => _TgExamCard(exam: exam, showLiveBadge: false),
            ),
          ],
          if (active.isEmpty && past.isEmpty && !service.loading)
            Text(
              'Görüntülenecek deneme yok.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.mutedOnPage(context),
              ),
            ),
        ],
        if (exams.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: service.loading ? null : () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Yenile'),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.mutedOnPage(context),
        letterSpacing: 0.2,
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
    final attempt = exam.myAttempt;
    final rank = attempt?.ranking;
    final participants = exam.participantCount;
    final showRank =
        exam.canAccessDetailedAnalysis && rank != null && participants > 0;
    final waitingResults = exam.isScoreCalculatedWaitingResults;
    final net = attempt?.net ?? 0;
    final showBadge = showLiveBadge && _isLiveNow && !exam.hasSubmittedAttempt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surfaceCard(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(color: AppTheme.champagne.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniRing(
                  percent: waitingResults ? 0 : exam.displaySuccessPercent,
                  centerLabel: waitingResults ? net.toStringAsFixed(1) : null,
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
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
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
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: waitingResults
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: waitingResults
                              ? AppTheme.champagne
                              : AppTheme.mutedOnPage(context),
                        ),
                      ),
                      if (showRank) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$participants kişi içinde $rank. oldun',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.champagne,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (waitingResults) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => _openSummary(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.mutedOnPage(context),
                  side: BorderSide(color: AppTheme.hairline(context)),
                ),
                child: const Text('Puan Özetini Gör'),
              ),
            ] else if (exam.canAccessDetailedAnalysis) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: exam.canAccessSolutions
                          ? () => _openSolutions(context)
                          : null,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Çözümleri İncele'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.champagne,
                        side: BorderSide(
                          color: AppTheme.champagne.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openAnalysis(context),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Detaylı Analiz'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.champagne,
                        foregroundColor: AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (!exam.hasSubmittedAttempt) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _openWelcome(context),
                  child: const Text('Denemeye git'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(TgExamModel exam) {
    if (exam.isScoreCalculatedWaitingResults) {
      if (exam.isAwaitingResultsPublication) {
        return 'Sınavı Tamamladın — Sonuçlar hesaplanıyor';
      }
      return 'Sınavı Tamamladın — Puanın Hesaplandı';
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

  void _openWelcome(BuildContext context) {
    Navigator.of(context).push(
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

  void _openAnalysis(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TgExamResultScreen(exam: exam),
      ),
    );
  }

  void _openSolutions(BuildContext context) {
    unawaited(TgExamResultScreen.openSolutionsReview(context, exam));
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.champagne.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        'Yayında',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.champagne,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MiniRing extends StatelessWidget {
  final double percent;
  final String? centerLabel;

  const _MiniRing({required this.percent, this.centerLabel});

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: centerLabel != null ? null : (value > 0 ? value : null),
            strokeWidth: 4,
            backgroundColor: AppTheme.hairline(context),
            color: AppTheme.champagne,
          ),
          Text(
            centerLabel ?? (percent > 0 ? '%${percent.round()}' : '—'),
            style: GoogleFonts.inter(
              fontSize: centerLabel != null ? 11 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
