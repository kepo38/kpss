import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/badge_model.dart';
import '../../services/content_bank_service.dart';
import '../../services/gamification_service.dart';
import '../../services/kpss_preference_service.dart';
import '../../services/pomodoro_service.dart';
import '../../services/practice_exam_service.dart';
import '../../services/topic_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_neon_palette.dart';
import '../../widgets/app_back_button.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _service = GamificationService.instance;

  static const _gold = AppTheme.champagne;
  static const _cyan = AppTheme.neonEdge;
  static const _goalPresets = [30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    unawaited(_service.initialize());
    unawaited(PracticeExamService.instance.initialize());
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = _service.stats;
    final badges = _service.badges;
    final earned = _service.earnedBadges.length;
    final next = _nextBadge(badges);
    final ink = AppTheme.onPage(context);

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.page(context),
        foregroundColor: ink,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Rozetler',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.pageTop(context),
              AppTheme.page(context),
              AppTheme.pageDeep(context),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
          children: [
            _LevelHero(stats: stats, totalXp: _service.totalXp),
            const SizedBox(height: 12),
            _DailyGoalCard(
              stats: stats,
              presets: _goalPresets,
              onGoalChanged: _service.setDailyGoal,
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              _NextBadgeCard(
                badge: next,
                progress: _progressFor(next),
                onTap: () => _openBadge(next),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Koleksiyon',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _gold.withValues(alpha: 0.16),
                    border: Border.all(color: _gold.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    '$earned / ${badges.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.92,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: badges.length,
              itemBuilder: (context, i) {
                final badge = badges[i];
                return _BadgeCard(
                  badge: badge,
                  neon: _neonFor(badge.id),
                  progress: _progressFor(badge),
                  onTap: () => _openBadge(badge),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  BadgeModel? _nextBadge(List<BadgeModel> badges) {
    final locked = badges.where((b) => !b.kazanildi).toList();
    if (locked.isEmpty) return null;
    locked.sort((a, b) {
      final pa = _progressFor(a).fraction;
      final pb = _progressFor(b).fraction;
      if (pb != pa) return pb.compareTo(pa);
      return a.xpOdulu.compareTo(b.xpOdulu);
    });
    return locked.first;
  }

  _BadgeProgress _progressFor(BadgeModel badge) {
    final stats = _service.stats;
    switch (badge.id) {
      case 'first_study':
        final n = ContentBankService.instance.allAttempts.isEmpty ? 0 : 1;
        return _BadgeProgress(n, 1);
      case 'streak_7':
        return _BadgeProgress(stats.streak.clamp(0, 7), 7);
      case 'daily_goal':
        return _BadgeProgress(
          stats.bugunCalismaDakika.clamp(0, stats.gunlukHedefDakika),
          math.max(1, stats.gunlukHedefDakika),
        );
      case 'exam_5':
        final n = PracticeExamService.instance.allExams.length.clamp(0, 5);
        return _BadgeProgress(n, 5);
      case 'topic_master':
        return _topicMasterProgress();
      case 'focus_10':
        final n = PomodoroService.instance.gecmis
            .where((s) => s.tamamlandi)
            .length
            .clamp(0, 10);
        return _BadgeProgress(n, 10);
      default:
        return badge.kazanildi ? const _BadgeProgress(1, 1) : const _BadgeProgress(0, 1);
    }
  }

  _BadgeProgress _topicMasterProgress() {
    final topics = TopicProgressService.instance
        .getTopics(KpssPreferenceService.instance.kpssType);
    if (topics.isEmpty) return const _BadgeProgress(0, 1);
    final byDers = <String, List<bool>>{};
    for (final t in topics) {
      byDers.putIfAbsent(t.dersAdi, () => []).add(t.tamamlandi);
    }
    var bestDone = 0;
    var bestTotal = 1;
    for (final list in byDers.values) {
      final done = list.where((v) => v).length;
      if (done / list.length > bestDone / bestTotal) {
        bestDone = done;
        bestTotal = list.length;
      }
    }
    return _BadgeProgress(bestDone, bestTotal);
  }

  Color _neonFor(String id) {
    return switch (id) {
      'first_study' => _cyan,
      'streak_7' => const Color(0xFFFB923C),
      'daily_goal' => const Color(0xFF34D399),
      'exam_5' => _gold,
      'topic_master' => const Color(0xFFA78BFA),
      'focus_10' => const Color(0xFFFB7185),
      _ => _gold,
    };
  }

  void _openBadge(BadgeModel badge) {
    final progress = _progressFor(badge);
    final neon = _neonFor(badge.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.inkSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final earnedOn = badge.kazanilmaTarihi;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: neon.withValues(alpha: 0.18),
                        border: Border.all(color: neon.withValues(alpha: 0.7)),
                        boxShadow: SubjectNeonPalette.glow(neon, blur: 10),
                      ),
                      child: Icon(badge.icon, color: neon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.ad,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            badge.kazanildi
                                ? earnedOn == null
                                    ? 'Kazanıldı'
                                    : 'Kazanıldı · ${DateFormat('d MMM yyyy').format(earnedOn.toLocal())}'
                                : '+${badge.xpOdulu} XP',
                            style: TextStyle(
                              fontSize: 12,
                              color: neon.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  badge.aciklama,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                if (!badge.kazanildi) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      color: neon,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: neon,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BadgeProgress {
  final int current;
  final int target;

  const _BadgeProgress(this.current, this.target);

  double get fraction =>
      target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);

  String get label => '$current / $target';
}

class _LevelHero extends StatelessWidget {
  final UserStatsModel stats;
  final int totalXp;

  const _LevelHero({required this.stats, required this.totalXp});

  @override
  Widget build(BuildContext context) {
    final next = math.max(1, stats.sonrakiSeviyeXp);
    final ring = (stats.xp / next).clamp(0.0, 1.0);
    final remain = (next - stats.xp).clamp(0, next);
    final hint = _hint(stats);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: SubjectNeonPalette.lightNeonModule(
        neon: AppTheme.champagne,
        accent: true,
        radius: 18,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 8,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: ring,
                    strokeWidth: 8,
                    color: AppTheme.champagneLight,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${stats.seviye}',
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'SEVİYE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppTheme.champagneLight.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(
                      icon: Icons.bolt_rounded,
                      label: '$totalXp XP',
                      neon: AppTheme.neonGold,
                    ),
                    _HeroPill(
                      icon: Icons.local_fire_department_rounded,
                      label: '${stats.streak} gün seri',
                      neon: const Color(0xFFFB923C),
                    ),
                    _HeroPill(
                      icon: Icons.flag_rounded,
                      label: remain == 0
                          ? 'Seviye atla'
                          : '$remain XP kaldı',
                      neon: AppTheme.neonEdge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hint(UserStatsModel stats) {
    if (stats.bugunCalismaDakika >= stats.gunlukHedefDakika &&
        stats.bugunCalismaDakika > 0) {
      return 'Günlük hedef tamam. Serin ${stats.streak} gün.';
    }
    if (stats.streak > 0 && stats.bugunCalismaDakika == 0) {
      return 'Serin tehlikede — bugün çalış.';
    }
    if (stats.streak == 0) {
      return 'İlk adımı at, serini başlat.';
    }
    final left =
        (stats.gunlukHedefDakika - stats.bugunCalismaDakika).clamp(0, 999);
    return 'Hedefe $left dk kaldı.';
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color neon;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.neon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: neon.withValues(alpha: 0.16),
        border: Border.all(color: neon.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: neon),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  final UserStatsModel stats;
  final List<int> presets;
  final ValueChanged<int> onGoalChanged;

  const _DailyGoalCard({
    required this.stats,
    required this.presets,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.onPage(context);
    final left =
        (stats.gunlukHedefDakika - stats.bugunCalismaDakika).clamp(0, 999);
    final done = stats.gunlukHedefIlerleme >= 1 && stats.bugunCalismaDakika > 0;
    final neon = done ? const Color(0xFF34D399) : AppTheme.neonEdge;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: SubjectNeonPalette.lightNeonModule(neon: neon, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.timer_outlined,
                color: neon,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Günlük hedef',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const Spacer(),
              Text(
                done ? 'Tamamlandı' : '$left dk kaldı',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: neon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: stats.gunlukHedefIlerleme.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: neon.withValues(alpha: 0.12),
              color: neon,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.bugunCalismaDakika} / ${stats.gunlukHedefDakika} dk',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mutedOnPage(context),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in presets)
                _GoalChip(
                  label: '$m dk',
                  selected: stats.gunlukHedefDakika == m,
                  neon: neon,
                  onTap: () => onGoalChanged(m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color neon;
  final VoidCallback onTap;

  const _GoalChip({
    required this.label,
    required this.selected,
    required this.neon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? neon.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(
              color: neon.withValues(alpha: selected ? 0.85 : 0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? neon : AppTheme.onPage(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextBadgeCard extends StatelessWidget {
  final BadgeModel badge;
  final _BadgeProgress progress;
  final VoidCallback onTap;

  const _NextBadgeCard({
    required this.badge,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const neon = AppTheme.champagne;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: SubjectNeonPalette.lightNeonModule(
            neon: neon,
            radius: 16,
          ),
          child: Row(
            children: [
              Icon(badge.icon, color: neon, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sıradaki: ${badge.ad}',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.onPage(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${badge.aciklama}  ·  ${progress.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: 6,
                        backgroundColor: neon.withValues(alpha: 0.12),
                        color: neon,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: neon.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  final Color neon;
  final _BadgeProgress progress;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.badge,
    required this.neon,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final earned = badge.kazanildi;
    final ink = AppTheme.onPage(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: earned
                  ? [
                      neon.withValues(alpha: 0.22),
                      AppTheme.surfaceCard(context),
                    ]
                  : [
                      AppTheme.surfaceCard(context),
                      AppTheme.surfaceCard(context),
                    ],
            ),
            border: Border.all(
              color: neon.withValues(alpha: earned ? 0.7 : 0.28),
              width: earned ? 1.2 : 1,
            ),
            boxShadow: earned ? SubjectNeonPalette.glow(neon, blur: 10) : null,
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: neon.withValues(alpha: earned ? 0.22 : 0.08),
                  border: Border.all(
                    color: neon.withValues(alpha: earned ? 0.85 : 0.3),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      badge.icon,
                      color: earned ? neon : neon.withValues(alpha: 0.42),
                      size: 24,
                    ),
                    if (!earned)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: neon.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge.ad,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: earned ? ink : ink.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                earned ? '+${badge.xpOdulu} XP' : progress.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: neon.withValues(alpha: earned ? 0.95 : 0.7),
                ),
              ),
              const Spacer(),
              if (!earned)
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 5,
                    backgroundColor: neon.withValues(alpha: 0.12),
                    color: neon,
                  ),
                )
              else
                Text(
                  'Kazanıldı',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: neon,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
