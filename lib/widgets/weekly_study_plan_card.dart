import 'package:flutter/material.dart';

import '../services/weekly_study_plan_service.dart';
import '../theme/app_theme.dart';
import 'pro_feature_lock.dart';
import 'pro_upsell_sheet.dart';

/// Haftalık çalışma planı — bugün açık, ilerisi Pro.
class WeeklyStudyPlanCard extends StatelessWidget {
  final List<WeeklyPlanDay> days;
  final bool isPremium;

  const WeeklyStudyPlanCard({
    super.key,
    required this.days,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final today = days.firstWhere((d) => d.isToday, orElse: () => days.first);
    final future = days.where((d) => !d.isToday).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'Haftalık Çalışma Planı',
          subtitle: 'Stratejik günlük rota',
        ),
        const SizedBox(height: 10),
        _DayBlock(day: today, highlighted: true),
        if (future.isNotEmpty) ...[
          const SizedBox(height: 10),
          ProFeatureLock(
            locked: !isPremium,
            upsellTitle: 'HAFTALIK PLAN',
            upsellSubtitle: 'Pro Üyeliğe Geç, Hedefin Olan Kamuya Atan',
            child: Column(
              children: [
                for (final day in future) ...[
                  _DayBlock(day: day, highlighted: false),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayBlock extends StatelessWidget {
  final WeeklyPlanDay day;
  final bool highlighted;

  const _DayBlock({required this.day, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: highlighted
            ? AppTheme.champagne.withValues(alpha: 0.1)
            : AppTheme.surfaceCard(context),
        border: Border.all(
          color: highlighted
              ? AppTheme.champagne.withValues(alpha: 0.45)
              : AppTheme.hairline(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                day.dayLabel,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onPage(context),
                ),
              ),
              if (highlighted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.champagne.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ÜCRETSİZ',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppTheme.champagne,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          for (final task in day.tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppTheme.mutedOnPage(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.onPage(context).withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                ],
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

/// Günlük ödev listesinde kilitli satır teaser.
class DailyMissionProTeaser extends StatelessWidget {
  final int hiddenCount;

  const DailyMissionProTeaser({super.key, required this.hiddenCount});

  @override
  Widget build(BuildContext context) {
    if (hiddenCount <= 0) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ProUpsellSheet.show(
          context,
          emoji: '📋',
          title: 'TÜM GÖREVLER',
          subtitle: 'Pro Üyeliğe Geç, Hedefin Olan Kamuya Atan',
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.45),
              width: 1.5,
            ),
            color: AppTheme.champagne.withValues(alpha: 0.06),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppTheme.champagne.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '+$hiddenCount görev daha · Pro ile tüm listeyi gör',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onPage(context).withValues(alpha: 0.85),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.champagne.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
