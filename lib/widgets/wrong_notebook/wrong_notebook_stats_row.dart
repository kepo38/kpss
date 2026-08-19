import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WrongNotebookStatsRow extends StatelessWidget {
  final int questionCount;
  final int subjectCount;
  final String? topSubject;
  final int? topSubjectCount;

  const WrongNotebookStatsRow({
    super.key,
    required this.questionCount,
    required this.subjectCount,
    this.topSubject,
    this.topSubjectCount,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);
    final card = AppTheme.surfaceCard(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.format_list_numbered_rounded,
              value: '$questionCount',
              label: 'Toplam yanlış',
              on: on,
              muted: muted,
              card: card,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.category_outlined,
              value: '$subjectCount',
              label: 'Ders',
              on: on,
              muted: muted,
              card: card,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.trending_up_rounded,
              value: topSubject ?? '—',
              label: 'En çok yanlış yapılan ders',
              cornerBadge: topSubjectCount?.toString(),
              on: on,
              muted: muted,
              card: card,
              compactValue: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color on;
  final Color muted;
  final Color card;
  final bool compactValue;
  final String? cornerBadge;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.on,
    required this.muted,
    required this.card,
    this.compactValue = false,
    this.cornerBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: card.withValues(alpha: 0.82),
        border: Border.all(color: AppTheme.hairline(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppTheme.champagne),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: compactValue ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: compactValue ? null : 'serif',
                  fontSize: compactValue ? 13 : 20,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: on,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: muted,
                ),
              ),
            ],
          ),
          if (cornerBadge != null)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE85D4C),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE85D4C).withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  cornerBadge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WrongNotebookInsightBanner extends StatelessWidget {
  const WrongNotebookInsightBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              AppTheme.ink.withValues(alpha: 0.04),
              AppTheme.champagne.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: AppTheme.champagne.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.champagne.withValues(alpha: 0.16),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: on.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bilinçli tekrar için sorular listede kalır. '
                'Doğru çöseniz bile otomatik silinmez.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: on.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
