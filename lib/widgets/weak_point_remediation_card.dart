import 'package:flutter/material.dart';

import '../models/quiz_result.dart';
import '../models/subject_performance.dart';
import '../services/ad_manager.dart';
import '../services/premium_service.dart';
import '../services/weak_point_remediation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/countdown_widget.dart';
import '../screens/quiz_screen.dart';
import 'pro_feature_lock.dart';
import 'pro_upsell_sheet.dart';
import 'scale_button.dart';

/// Zayıf nokta telafi testi — en çok yanlış 3 konu (Pro).
class WeakPointRemediationCard extends StatefulWidget {
  final KpssType kpssType;
  final bool isPremium;

  const WeakPointRemediationCard({
    super.key,
    required this.kpssType,
    required this.isPremium,
  });

  @override
  State<WeakPointRemediationCard> createState() =>
      _WeakPointRemediationCardState();
}

class _WeakPointRemediationCardState extends State<WeakPointRemediationCard> {
  bool _loading = false;

  Future<void> _startRemediation() async {
    if (!PremiumService.instance.isPremium) {
      await ProUpsellSheet.show(
        context,
        emoji: '🚨',
        title: 'TELAFİ TESTİ',
        subtitle: kProUpsellSubtitle,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final questions = await WeakPointRemediationService.instance
          .fetchRemediationPack(widget.kpssType);
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Telafi testi için yeterli zayıf konu verisi yok.'),
          ),
        );
        return;
      }

      AdManager.instance.skipNextPageTransition();
      await Navigator.of(context).push<QuizResult>(
        MaterialPageRoute<QuizResult>(
          builder: (_) => QuizScreen(
            title: 'Zayıf Nokta Telafi',
            questions: questions,
            suppressWrongNotebookHint: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weak = WeakPointRemediationService.instance
        .topWeakTopics(widget.kpssType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'Kırmızı Alarm',
          subtitle: 'Zayıf nokta otomatik telafi testi',
        ),
        const SizedBox(height: 10),
        ProFeatureLock(
          locked: !widget.isPremium,
          upsellTitle: 'TELAFİ TESTİ',
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
                  const Color(0xFF450A0A).withValues(alpha: 0.35),
                  AppTheme.surfaceCard(context),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFF87171).withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFF87171).withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        weak.isEmpty
                            ? 'Henüz zayıf konu tespiti yok'
                            : 'En çok yanlış ${weak.length} konu',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onPage(context),
                        ),
                      ),
                    ),
                  ],
                ),
                if (weak.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final topic in weak)
                    _WeakTopicRow(stat: topic),
                ],
                const SizedBox(height: 14),
                ScaleButton(
                  onPressed: _loading ? null : _startRemediation,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF87171),
                          const Color(0xFFDC2626),
                        ],
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Telafi Testi Başlat',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
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

class _WeakTopicRow extends StatelessWidget {
  final WeakTopicStat stat;

  const _WeakTopicRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFF87171),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stat.topicName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onPage(context).withValues(alpha: 0.9),
              ),
            ),
          ),
          Text(
            '${stat.wrongCount} yanlış',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF87171).withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
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
            color: const Color(0xFFF87171).withValues(alpha: 0.95),
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
