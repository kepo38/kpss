import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/daily_mini_exam_constants.dart';
import '../constants/savings_constants.dart';
import '../screens/premium/premium_paywall_screen.dart';
import '../services/daily_mini_exam_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/daily_mini_exam/daily_mini_odul_button.dart';
import '../widgets/frosted_email.dart';
import '../widgets/scale_button.dart';

/// Günün Mini Denemesi tam sıralama ekranı (günlük liste; hafta/ay ÖDÜL ayrı).
class DailyMiniExamResultScreen extends StatefulWidget {
  const DailyMiniExamResultScreen({super.key});

  @override
  State<DailyMiniExamResultScreen> createState() =>
      _DailyMiniExamResultScreenState();
}

class _DailyMiniExamResultScreenState extends State<DailyMiniExamResultScreen> {
  bool _loadingBoard = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadTodayRanking());
    });
  }

  Future<void> _loadTodayRanking() async {
    setState(() => _loadingBoard = true);
    await DailyMiniExamService.instance.refresh();
    if (!mounted) return;
    setState(() => _loadingBoard = false);
  }

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
        final rank = service.rankForCurrentUser() ?? attempt.rank;
        final showRank = rank != null && rank > 0 && participantCount > 0;
        final boardEmpty = leaderboard.isEmpty;

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
            actions: [
              IconButton(
                tooltip: 'Yenile',
                onPressed: _loadingBoard ? null : _loadTodayRanking,
                icon: _loadingBoard
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.champagne,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  child: DailyMiniOdulButton(
                    size: 44,
                    onPressed: () => showDailyMiniOdulInfoCard(context),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
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
          if (showRank) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.champagne.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text(
                        '$rank. sıradasın',
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.champagneLight,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gün içinde sürekli güncellenmektedir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.25,
                      fontStyle: FontStyle.italic,
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
          if (_loadingBoard && boardEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.champagne),
              ),
            )
          else if (boardEmpty)
            Text(
              service.rankingSubmitPending
                  ? 'Sıralaman sunucuya iletiliyor. Biraz sonra yenile.'
                  : 'Bugün henüz sıralama kaydı yok veya veriler yüklenemedi.',
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
                      color: row.rank == rank
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
          const SizedBox(height: 8),
        ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            PlayBillingService.instance.premiumNotifier,
                        builder: (context, billingPremium, _) {
                          final isPremium = billingPremium ||
                              PremiumService.instance.isPremium;
                          if (isPremium) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PdfUpsellRow(
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const PremiumPaywallScreen(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppTheme.champagne,
                          foregroundColor: AppTheme.ink,
                          minimumSize: const Size.fromHeight(40),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Devam Et',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
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
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
              color: AppTheme.neonGold.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppTheme.ink,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Bu ayın yanlış çözümleri',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.ink,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '$priceTl TL',
                style: const TextStyle(
                  fontSize: 11,
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
