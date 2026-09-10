import 'package:flutter/material.dart';

import '../services/weekly_study_plan_service.dart';
import '../theme/app_theme.dart';
import 'pro_feature_lock.dart';
import 'pro_upsell_sheet.dart';

/// Haftalık çalışma planı — canlı hafta şeridi, bugün öne çıkar, ilerisi Pro.
class WeeklyStudyPlanCard extends StatefulWidget {
  final List<WeeklyPlanDay> days;
  final bool isPremium;

  const WeeklyStudyPlanCard({
    super.key,
    required this.days,
    required this.isPremium,
  });

  @override
  State<WeeklyStudyPlanCard> createState() => _WeeklyStudyPlanCardState();
}

class _WeeklyStudyPlanCardState extends State<WeeklyStudyPlanCard>
    with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.days.indexWhere((d) => d.isToday);
    if (_selectedIndex < 0) _selectedIndex = 0;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectDay(int index) {
    if (index == _selectedIndex) return;
    if (!widget.isPremium && index > 0) {
      ProUpsellSheet.show(
        context,
        emoji: '📋',
        title: 'HAFTALIK PLAN',
        subtitle: kProUpsellSubtitle,
      );
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();

    final selected = days[_selectedIndex.clamp(0, days.length - 1)];
    final todayIndex = days.indexWhere((d) => d.isToday).clamp(0, days.length - 1);
    final weekProgress = (todayIndex + 1) / days.length;
    final totalTasks = days.fold<int>(0, (sum, d) => sum + d.tasks.length);
    final weakCount = _weakTopicCount(days);
    final subjectCount = _subjectCount(days);
    final dynamicHint = _dynamicHint(days, weakCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PremiumPlanShell(
          child: Column(
            children: [
              _CompactPlanHeader(
                weekProgress: weekProgress,
                totalTasks: totalTasks,
                dynamicHint: dynamicHint,
                weakCount: weakCount,
                subjectCount: subjectCount,
                pulse: _pulseController,
              ),
              const SizedBox(height: 12),
              _WeekTimeline(
                days: days,
                selectedIndex: _selectedIndex,
                isPremium: widget.isPremium,
                weekProgress: weekProgress,
                onSelect: _selectDay,
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0.02),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _SelectedDayPanel(
                  key: ValueKey(selected.date),
                  day: selected,
                  dayIndex: _selectedIndex,
                  isPremium: widget.isPremium,
                ),
              ),
              if (!widget.isPremium && days.length > 1) ...[
                const SizedBox(height: 10),
                _LockedWeekTeaser(hiddenDayCount: days.length - 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  int _weakTopicCount(List<WeeklyPlanDay> days) {
    return days.fold<int>(
      0,
      (sum, d) =>
          sum +
          d.tasks.where((t) => t.toLowerCase().contains('zayıf')).length,
    );
  }

  int _subjectCount(List<WeeklyPlanDay> days) {
    final subjects = <String>{};
    for (final day in days) {
      for (final task in day.tasks) {
        final lower = task.toLowerCase();
        if (lower.contains('konu testi') ||
            lower.contains('günlük') ||
            lower.contains('tekrar')) {
          final name = task.split(RegExp(r'[—\-]')).first.trim();
          if (name.isNotEmpty) subjects.add(name);
        }
      }
    }
    return subjects.length.clamp(1, 99);
  }

  String _dynamicHint(List<WeeklyPlanDay> days, int weakCount) {
    if (weakCount > 0) {
      return weakCount == 1
          ? 'Zayıf konuna göre rota güncellendi'
          : '$weakCount zayıf konuya göre rota güncellendi';
    }
    final pending = days.first.tasks.where(
      (t) => t.toLowerCase().contains('konu testi'),
    ).length;
    if (pending > 0) return '$pending ders için günlük rota hazır';
    return 'Performansına göre haftalık rota';
  }
}

/// Başlık + performans özeti tek satırda; kart dışına taşmaz.
class _CompactPlanHeader extends StatelessWidget {
  final double weekProgress;
  final int totalTasks;
  final String dynamicHint;
  final int weakCount;
  final int subjectCount;
  final Animation<double> pulse;

  const _CompactPlanHeader({
    required this.weekProgress,
    required this.totalTasks,
    required this.dynamicHint,
    required this.weakCount,
    required this.subjectCount,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'HAFTALIK ÇALIŞMA PLANI',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.champagne.withValues(alpha: 0.98),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dynamicHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedOnPage(context),
                    ),
                  ),
                ],
              ),
            ),
            _LiveBadge(pulse: pulse),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.champagne.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 13,
                    color: AppTheme.champagne.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalTasks görev',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: AppTheme.champagne,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: weekProgress.clamp(0.08, 1.0),
                  minHeight: 5,
                  backgroundColor: AppTheme.champagne.withValues(alpha: 0.1),
                  color: AppTheme.champagne,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Hafta ${(weekProgress * 100).round()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: AppTheme.champagne.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _EngineChip(
              icon: Icons.track_changes_rounded,
              label: weakCount > 0 ? '$weakCount telafi' : 'Telafi yok',
              accent: weakCount > 0 ? const Color(0xFFF87171) : null,
            ),
            _EngineChip(
              icon: Icons.menu_book_rounded,
              label: '$subjectCount ders',
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final Animation<double> pulse;

  const _LiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF34D399).withValues(alpha: 0.1 + pulse.value * 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF34D399).withValues(alpha: 0.35 + pulse.value * 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    const Color(0xFF34D399),
                    const Color(0xFF6EE7B7),
                    pulse.value,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.35 + pulse.value * 0.25),
                      blurRadius: 6 + pulse.value * 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'CANLI',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Color(0xFF6EE7B7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EngineChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _EngineChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.champagne;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.withValues(alpha: 0.95)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPlanShell extends StatelessWidget {
  final Widget child;

  const _PremiumPlanShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.surfaceCard(context),
                      AppTheme.page(context),
                      AppTheme.pageDeep(context).withValues(alpha: 0.6),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.champagne.withValues(alpha: 0.12),
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
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.champagne.withValues(alpha: 0.05),
                      AppTheme.champagne.withValues(alpha: 0.45),
                      AppTheme.champagne.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekTimeline extends StatelessWidget {
  final List<WeeklyPlanDay> days;
  final int selectedIndex;
  final bool isPremium;
  final double weekProgress;
  final ValueChanged<int> onSelect;

  const _WeekTimeline({
    required this.days,
    required this.selectedIndex,
    required this.isPremium,
    required this.weekProgress,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 28,
            right: 28,
            top: 36,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: weekProgress.clamp(0.05, 1.0),
                minHeight: 3,
                backgroundColor: AppTheme.champagne.withValues(alpha: 0.08),
                color: AppTheme.champagne.withValues(alpha: 0.45),
              ),
            ),
          ),
          ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = days[index];
              final selected = index == selectedIndex;
              final locked = !isPremium && index > 0;
              return _WeekDayChip(
                day: day,
                selected: selected,
                locked: locked,
                onTap: () => onSelect(index),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  final WeeklyPlanDay day;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _WeekDayChip({
    required this.day,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 76,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.champagne.withValues(alpha: 0.28),
                      AppTheme.champagne.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            color: selected
                ? null
                : AppTheme.surfaceCard(context).withValues(alpha: 0.85),
            border: Border.all(
              color: selected
                  ? AppTheme.champagne.withValues(alpha: 0.75)
                  : day.isToday
                      ? AppTheme.champagne.withValues(alpha: 0.35)
                      : AppTheme.hairline(context),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : day.isToday
                    ? [
                        BoxShadow(
                          color: AppTheme.champagne.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 12,
                child: Center(
                  child: day.isToday
                      ? Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? AppTheme.champagne
                                : AppTheme.champagne.withValues(alpha: 0.55),
                          ),
                        )
                      : locked
                          ? Icon(
                              Icons.lock_rounded,
                              size: 11,
                              color: muted.withValues(alpha: 0.55),
                            )
                          : null,
                ),
              ),
              Text(
                day.dayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                  color: selected
                      ? AppTheme.champagne
                      : on.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.date.day}',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: selected ? on : muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.tasks.length}',
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppTheme.champagne.withValues(alpha: 0.95)
                      : muted.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  final WeeklyPlanDay day;
  final int dayIndex;
  final bool isPremium;

  const _SelectedDayPanel({
    super.key,
    required this.day,
    required this.dayIndex,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    const maxVisibleTasks = 3;
    final visibleTasks = day.tasks.take(maxVisibleTasks).toList();
    final hiddenCount = day.tasks.length - visibleTasks.length;

    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: day.isToday ? 0.16 : 0.06),
            blurRadius: day.isToday ? 20 : 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: day.isToday
                        ? const [
                            Color(0xFF1A2438),
                            Color(0xFF121A2A),
                            Color(0xFF0C1424),
                          ]
                        : [
                            AppTheme.surfaceCard(context),
                            AppTheme.page(context),
                          ],
                  ),
                ),
              ),
            ),
            if (day.isToday) ...[
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.champagne.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -16,
                bottom: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFC41E3A).withValues(alpha: 0.14),
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
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day.dayLabel,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: day.isToday
                                    ? Colors.white
                                    : AppTheme.onPage(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(day.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: day.isToday
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : AppTheme.mutedOnPage(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (day.isToday && !isPremium)
                        _StatusBadge(
                          label: 'ÜCRETSİZ',
                          filled: true,
                          light: day.isToday,
                        )
                      else if (day.isToday)
                        _StatusBadge(
                          label: 'AKTİF',
                          filled: true,
                          light: day.isToday,
                        )
                      else
                        _StatusBadge(
                          label: 'Gün ${dayIndex + 1}',
                          filled: false,
                          light: day.isToday,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DayTaskSummaryBar(
                    taskCount: day.tasks.length,
                    dark: day.isToday,
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < visibleTasks.length; i++) ...[
                    _AnimatedTaskTile(
                      key: ValueKey('${day.date}-$i'),
                      task: visibleTasks[i],
                      index: i + 1,
                      dark: day.isToday,
                      delayMs: i * 45,
                    ),
                    if (i < visibleTasks.length - 1) const SizedBox(height: 8),
                  ],
                  if (hiddenCount > 0) ...[
                    const SizedBox(height: 10),
                    DailyMissionProTeaser(
                      hiddenCount: hiddenCount,
                      light: day.isToday,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (day.isToday || isPremium) return content;

    return ProFeatureLock(
      locked: true,
      upsellTitle: 'HAFTALIK PLAN',
      upsellSubtitle: kProUpsellSubtitle,
      child: content,
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _DayTaskSummaryBar extends StatelessWidget {
  final int taskCount;
  final bool dark;

  const _DayTaskSummaryBar({
    required this.taskCount,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final track = dark
        ? Colors.white.withValues(alpha: 0.1)
        : AppTheme.champagne.withValues(alpha: 0.12);
    final fill = dark ? AppTheme.champagne : AppTheme.champagne.withValues(alpha: 0.85);
    final label = dark
        ? Colors.white.withValues(alpha: 0.6)
        : AppTheme.mutedOnPage(context);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (taskCount / 6).clamp(0.15, 1.0),
              minHeight: 4,
              backgroundColor: track,
              color: fill,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$taskCount görev · ~${taskCount * 12} dk',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: label,
          ),
        ),
      ],
    );
  }
}

class _AnimatedTaskTile extends StatefulWidget {
  final String task;
  final int index;
  final bool dark;
  final int delayMs;

  const _AnimatedTaskTile({
    super.key,
    required this.task,
    required this.index,
    required this.dark,
    required this.delayMs,
  });

  @override
  State<_AnimatedTaskTile> createState() => _AnimatedTaskTileState();
}

class _AnimatedTaskTileState extends State<_AnimatedTaskTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _PlanTaskTile(
          task: widget.task,
          index: widget.index,
          dark: widget.dark,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool filled;
  final bool light;

  const _StatusBadge({
    required this.label,
    required this.filled,
    required this.light,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? (light
                ? AppTheme.champagne.withValues(alpha: 0.18)
                : AppTheme.champagne.withValues(alpha: 0.12))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: light ? 0.45 : 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: light ? AppTheme.champagneLight : AppTheme.champagne,
        ),
      ),
    );
  }
}

class _PlanTaskTile extends StatelessWidget {
  final String task;
  final int index;
  final bool dark;

  const _PlanTaskTile({
    required this.task,
    required this.index,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _taskMeta(task);
    final textColor = dark ? Colors.white : AppTheme.onPage(context);
    final muted = dark
        ? Colors.white.withValues(alpha: 0.55)
        : AppTheme.mutedOnPage(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : AppTheme.champagne.withValues(alpha: 0.05),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.hairline(context),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  meta.color.withValues(alpha: dark ? 0.28 : 0.18),
                  meta.color.withValues(alpha: dark ? 0.1 : 0.06),
                ],
              ),
              border: Border.all(color: meta.color.withValues(alpha: 0.35)),
            ),
            child: Icon(meta.icon, size: 17, color: meta.color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.category,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: meta.color.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  task,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          Text(
            index.toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  _TaskMeta _taskMeta(String task) {
    final lower = task.toLowerCase();
    if (lower.contains('zayıf')) {
      return const _TaskMeta(
        icon: Icons.track_changes_rounded,
        category: 'TELAFİ',
        color: Color(0xFFF87171),
      );
    }
    if (lower.contains('deneme')) {
      return const _TaskMeta(
        icon: Icons.emoji_events_outlined,
        category: 'SİMÜLASYON',
        color: Color(0xFF60A5FA),
      );
    }
    if (lower.contains('tamam')) {
      return const _TaskMeta(
        icon: Icons.celebration_outlined,
        category: 'TAMAMLANDI',
        color: Color(0xFF34D399),
      );
    }
    if (lower.contains('konu testi') || lower.contains('günlük')) {
      return const _TaskMeta(
        icon: Icons.quiz_outlined,
        category: 'KONU TESTİ',
        color: AppTheme.champagne,
      );
    }
    return const _TaskMeta(
      icon: Icons.task_alt_outlined,
      category: 'GÖREV',
      color: AppTheme.champagneLight,
    );
  }
}

class _TaskMeta {
  final IconData icon;
  final String category;
  final Color color;

  const _TaskMeta({
    required this.icon,
    required this.category,
    required this.color,
  });
}

class _LockedWeekTeaser extends StatelessWidget {
  final int hiddenDayCount;

  const _LockedWeekTeaser({required this.hiddenDayCount});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ProUpsellSheet.show(
          context,
          emoji: '📋',
          title: 'HAFTALIK PLAN',
          subtitle: kProUpsellSubtitle,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.38),
            ),
            gradient: LinearGradient(
              colors: [
                AppTheme.champagne.withValues(alpha: 0.08),
                AppTheme.champagne.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: AppTheme.champagne.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '+$hiddenDayCount günün tam rotası Pro\'da',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onPage(context).withValues(alpha: 0.88),
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

/// Günlük ödev listesinde kilitli satır teaser — Pro upsell CTA.
class DailyMissionProTeaser extends StatelessWidget {
  final int hiddenCount;
  final bool light;

  const DailyMissionProTeaser({
    super.key,
    required this.hiddenCount,
    this.light = false,
  });

  void _openUpsell(BuildContext context) {
    ProUpsellSheet.show(
      context,
      emoji: '📋',
      title: 'TÜM GÖREVLER',
      subtitle: kProUpsellSubtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hiddenCount <= 0) return const SizedBox.shrink();

    final onDark = light;
    final titleColor = Colors.white;
    final accentColor = AppTheme.champagneLight;
    final subtitleColor = onDark
        ? Colors.white.withValues(alpha: 0.72)
        : AppTheme.champagneLight.withValues(alpha: 0.88);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUpsell(context),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: onDark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A2438),
                      Color(0xFF141C2E),
                      Color(0xFF0C1424),
                    ],
                    stops: [0, 0.55, 1],
                  ),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: onDark ? 0.38 : 0.44),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: onDark ? 0.12 : 0.18),
                blurRadius: onDark ? 12 : 18,
                offset: const Offset(0, 6),
              ),
              if (!onDark)
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!onDark)
                Positioned(
                  right: -18,
                  top: -22,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.champagne.withValues(alpha: 0.18),
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
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6B0F1A).withValues(alpha: onDark ? 0.5 : 1),
                        AppTheme.champagne,
                        const Color(0xFFFFE7B8).withValues(alpha: onDark ? 0.75 : 1),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: onDark
                              ? [
                                  AppTheme.champagne.withValues(alpha: 0.28),
                                  AppTheme.champagne.withValues(alpha: 0.1),
                                ]
                              : const [
                                  Color(0xFFFFF8EE),
                                  Color(0xFFE8CF98),
                                  Color(0xFFC9A86C),
                                ],
                        ),
                        border: Border.all(
                          color: AppTheme.champagneLight.withValues(
                            alpha: onDark ? 0.45 : 0.65,
                          ),
                        ),
                        boxShadow: onDark
                            ? null
                            : [
                                BoxShadow(
                                  color: AppTheme.champagne.withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 17,
                        color: onDark ? AppTheme.champagneLight : AppTheme.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'serif',
                                height: 1.1,
                              ),
                              children: [
                                TextSpan(
                                  text: '+$hiddenCount',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: accentColor,
                                  ),
                                ),
                                TextSpan(
                                  text: ' görev daha',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Görevleri Tamamla',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
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
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: AppTheme.ink,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppTheme.ink,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
