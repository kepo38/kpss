import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/badge_model.dart';
import '../../services/gamification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _service = GamificationService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    unawaited(_service.initialize());
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

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Rozetler & Motivasyon'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatsHeader(stats: stats),
          const SizedBox(height: 12),
          _DailyGoalCard(
            stats: stats,
            onGoalChanged: (m) {
              setState(() => _service.setDailyGoal(m));
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Rozetler (${_service.earnedBadges.length}/${badges.length})',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: AppTheme.lightPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: badges.length,
            itemBuilder: (context, i) {
              final badge = badges[i];
              return _BadgeCard(badge: badge);
            },
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final UserStatsModel stats;

  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(label: 'Seviye', value: '${stats.seviye}'),
            _StatItem(label: 'XP', value: '${stats.xp}'),
            _StatItem(
              label: 'Seri',
              value: '${stats.streak} gün',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null) Icon(icon, color: color, size: 28),
        Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.inter(fontSize: 12)),
      ],
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  final UserStatsModel stats;
  final ValueChanged<int> onGoalChanged;

  const _DailyGoalCard({required this.stats, required this.onGoalChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Günlük Hedef', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: stats.gunlukHedefIlerleme.clamp(0.0, 1.0),
              backgroundColor: AppTheme.lightAccent.withValues(alpha: 0.2),
              color: AppTheme.lightPrimary,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${stats.bugunCalismaDakika} / ${stats.gunlukHedefDakika} dk',
            ),
            Slider(
              value: stats.gunlukHedefDakika.toDouble(),
              min: 30,
              max: 480,
              divisions: 15,
              label: '${stats.gunlukHedefDakika} dk',
              onChanged: (v) => onGoalChanged(v.round()),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final earned = badge.kazanildi;
    return Card(
      color: earned ? null : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              badge.icon,
              size: 36,
              color: earned ? AppTheme.lightAccent : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              badge.ad,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: earned ? null : Colors.grey,
              ),
            ),
            Text(
              '+${badge.xpOdulu} XP',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.lightAccent),
            ),
          ],
        ),
      ),
    );
  }
}
