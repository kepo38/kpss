import 'package:flutter/material.dart';

import '../services/ai_coach_service.dart';
import '../theme/app_theme.dart';
import 'pro_feature_lock.dart';

/// HEDEF KAMU koç yorumu — premium insight kartı.
class AiCoachInsightCard extends StatelessWidget {
  final CoachInsight? insight;
  final bool isPremium;
  final String fallbackMessage;

  const AiCoachInsightCard({
    super.key,
    required this.insight,
    required this.isPremium,
    this.fallbackMessage =
        'Son 3 testtir coğrafyada patlıyorsun, çalışman gereken alt konu '
        'Türkiye\'nin Coğrafi Bölgeleri\'dir.',
  });

  @override
  Widget build(BuildContext context) {
    final message = insight?.message ?? fallbackMessage;
    final subject = insight?.subject;
    final topic = insight?.topic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CoachSectionHeader(),
        const SizedBox(height: 12),
        ProFeatureLock(
          locked: !isPremium,
          upsellTitle: 'AI KOÇ',
          upsellSubtitle: kProUpsellSubtitle,
          child: _PremiumCoachCard(
            message: message,
            subject: subject,
            topic: topic,
          ),
        ),
      ],
    );
  }
}

class _CoachSectionHeader extends StatelessWidget {
  const _CoachSectionHeader();

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
                Color(0xFFFFE7B8),
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
                'HEDEF KAMU KOÇLUK',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.champagne.withValues(alpha: 0.98),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Trend analizi ve kişisel yorum',
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

class _PremiumCoachCard extends StatelessWidget {
  final String message;
  final String? subject;
  final String? topic;

  const _PremiumCoachCard({
    required this.message,
    this.subject,
    this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF8B1538).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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
              right: -28,
              top: -36,
              child: Container(
                width: 140,
                height: 140,
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
              left: -18,
              bottom: -24,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC41E3A).withValues(alpha: 0.16),
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
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.champagne.withValues(alpha: 0.28),
                              AppTheme.champagne.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: AppTheme.champagneLight.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.champagne.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.champagneLight,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Koç yorumu',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppTheme.champagne.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'KİŞİSEL ANALİZ',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                  color: AppTheme.champagneLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '“',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 34,
                            height: 0.85,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.champagne.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 15.5,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                            color: Colors.white.withValues(alpha: 0.94),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subject != null || topic != null) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (subject != null)
                          _InsightChip(
                            icon: Icons.menu_book_outlined,
                            label: subject!,
                          ),
                        if (topic != null)
                          _InsightChip(
                            icon: Icons.track_changes_rounded,
                            label: topic!,
                            accent: true,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;

  const _InsightChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppTheme.champagneLight : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? AppTheme.champagne.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent
              ? AppTheme.champagne.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}
