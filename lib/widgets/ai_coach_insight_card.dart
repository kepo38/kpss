import 'package:flutter/material.dart';

import '../services/ai_coach_service.dart';
import '../theme/app_theme.dart';
import 'pro_feature_lock.dart';

/// Yapay zeka koç yorumu kartı.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          title: 'HEDEF KAMU KOÇLUK',
          subtitle: 'Trend analizi ve kişisel yorum',
        ),
        const SizedBox(height: 10),
        ProFeatureLock(
          locked: !isPremium,
          upsellTitle: 'AI KOÇ',
          upsellSubtitle: kProUpsellSubtitle,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B),
                  AppTheme.inkSoft.withValues(alpha: 0.95),
                ],
              ),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.champagne.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_outlined,
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
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.champagneLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: AppTheme.champagne.withValues(alpha: 0.95),
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
    );
  }
}
