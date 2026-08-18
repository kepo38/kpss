import 'package:flutter/material.dart';

import '../constants/daily_mini_exam_constants.dart';
import '../constants/savings_constants.dart';
import '../screens/premium/premium_paywall_screen.dart';
import '../services/daily_mini_exam_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/frosted_email.dart';
import '../widgets/scale_button.dart';

/// Günün Mini Denemesi tam sıralama ekranı.
class DailyMiniExamResultScreen extends StatelessWidget {
  const DailyMiniExamResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DailyMiniExamService.instance,
      builder: (context, _) {
        final service = DailyMiniExamService.instance;
        final attempt = service.attempt;
        if (attempt == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ink,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.champagne),
            ),
          );
        }
        final participantCount = service.participantCount;
        final leaderboard = service.leaderboard;
        final rankLine = attempt.rank != null && participantCount > 0
            ? '${attempt.rank}. sıra · ${formatTrInt(participantCount)} kişi'
            : null;

        return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Günün Sıralaması',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
        children: [
          Text(
            'BUGÜNKÜ SKOR',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppTheme.champagne.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${attempt.correct}',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 56,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: ' / ${attempt.total}',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '${attempt.wrong} yanlış'
            '${attempt.blank > 0 ? ' · ${attempt.blank} boş' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          if (attempt.durationSeconds > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Süre: ${formatExamDuration(attempt.durationSeconds)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.champagne.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (rankLine != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.champagne.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Senin Sıran: $rankLine',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.champagneLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            'EN BAŞARILI ADAYLAR',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
              color: AppTheme.champagne.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          if (leaderboard.isEmpty)
            Text(
              'Sıralama verileri yenileniyor. Kısa süre sonra tekrar bakabilirsin.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            )
          else
            for (final row in leaderboard)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: row.rank == attempt.rank
                          ? AppTheme.champagne.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${row.rank}',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: row.rank <= 3
                                ? AppTheme.champagneLight
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (row.displayName.isNotEmpty)
                              Text(
                                row.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            FrostedEmail(
                              prefix: row.emailPrefix,
                              rest: row.emailRest,
                              style: TextStyle(
                                fontSize: row.displayName.isNotEmpty ? 11 : 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(
                                  alpha: row.displayName.isNotEmpty ? 0.55 : 0.9,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${row.correct}/${DailyMiniExamConstants.questionCount}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (row.durationSeconds > 0)
                            Text(
                              formatExamDuration(row.durationSeconds),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 22),
          ValueListenableBuilder<bool>(
            valueListenable: PlayBillingService.instance.premiumNotifier,
            builder: (context, billingPremium, _) {
              final isPremium =
                  billingPremium || PremiumService.instance.isPremium;
              if (isPremium) return const SizedBox.shrink();
              return Column(
                children: [
                  _PdfUpsellRow(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const PremiumPaywallScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.champagne,
              foregroundColor: AppTheme.ink,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Tamam',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}

class _PdfUpsellRow extends StatelessWidget {
  final VoidCallback onTap;

  const _PdfUpsellRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const priceTl = SavingsConstants.paywallMonthlyHighlightTl;

    return ScaleButton(
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFEDB0),
              Color(0xFFE8C878),
              AppTheme.champagne,
            ],
          ),
          border: Border.all(
            color: const Color(0xFFFFE5A0).withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonGold.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppTheme.ink,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Bu ayın yanlış çözümleri',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$priceTl TL',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.champagneLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
