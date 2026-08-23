import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/tg_exam_models.dart';
import '../../services/tg_exam_analysis_helper.dart';
import '../../theme/app_theme.dart';
import '../pro_feature_lock.dart';

/// Deneme bitişi kritik an — Türkiye geneli analiz teaser (Pro kilitli).
class TgExamProAnalysisTeaser extends StatelessWidget {
  final TgExamModel exam;
  final bool isPremium;
  final VoidCallback? onOpenFullAnalysis;

  const TgExamProAnalysisTeaser({
    super.key,
    required this.exam,
    required this.isPremium,
    this.onOpenFullAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    final attempt = exam.myAttempt;
    final canRanking = exam.canAccessDetailedAnalysis;
    final rank = attempt?.ranking;
    final participants = exam.participantCount;
    final percentile = canRanking
        ? TgExamAnalysisHelper.percentileLabel(
            ranking: rank,
            participantCount: participants,
          )
        : null;
    final fireSubjects =
        TgExamAnalysisHelper.fireSubjectLabels(attempt?.subjectNets ?? {});

    final preview = _AnalysisPreview(
      percentile: percentile,
      fireSubjects: fireSubjects,
      waitingRanking: !canRanking,
      averageNet: exam.averageNet,
      userNet: attempt?.net,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Türkiye Geneli Analiz',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppTheme.champagne,
          ),
        ),
        const SizedBox(height: 12),
        ProFeatureLock(
          locked: !isPremium,
          upsellTitle: 'TÜRKİYE GENELİ ANALİZ',
          upsellSubtitle: TgExamAnalysisHelper.proUpsellSubtitle,
          child: preview,
        ),
        if (isPremium && exam.canAccessDetailedAnalysis && onOpenFullAnalysis != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpenFullAnalysis,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Detaylı Analizi Gör'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: AppTheme.ink,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ] else if (!isPremium) ...[
          const SizedBox(height: 10),
          Text(
            TgExamAnalysisHelper.proUpsellSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ] else if (!canRanking) ...[
          const SizedBox(height: 8),
          Text(
            'Yüzdelik dilim ve sıralama, sonuçlar açıklandığında burada görünür.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.48),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalysisPreview extends StatelessWidget {
  final String? percentile;
  final List<String> fireSubjects;
  final bool waitingRanking;
  final double? averageNet;
  final double? userNet;

  const _AnalysisPreview({
    required this.percentile,
    required this.fireSubjects,
    required this.waitingRanking,
    this.averageNet,
    this.userNet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.champagne.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.public_outlined,
                size: 22,
                color: AppTheme.champagne.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waitingRanking
                          ? 'Yüzdelik dilim — sonuçlar açıklanınca'
                          : (percentile ?? 'Sıralama hesaplanıyor'),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                    if (!waitingRanking &&
                        averageNet != null &&
                        userNet != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Netin ${userNet!.toStringAsFixed(2)} · Türkiye ort. '
                        '${averageNet!.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Fire verdiğin dersler',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppTheme.champagne.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 8),
          if (fireSubjects.isEmpty)
            Text(
              waitingRanking
                  ? 'Ders bazlı net dağılımın sonuçlar açıklanınca görünür.'
                  : 'Ders dağılımı henüz yok.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            )
          else
            ...fireSubjects.map(
              (subject) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_down_rounded,
                      size: 16,
                      color: const Color(0xFFF87171).withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subject,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
