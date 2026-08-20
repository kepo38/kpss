import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_mini_ranking_models.dart';
import '../models/leaderboard_model.dart';
import '../services/daily_mini_ranking_service.dart';
import '../theme/app_theme.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/app_back_button.dart';
import '../widgets/frosted_email.dart';

/// Haftalık/aylık mini deneme sıralaması + geçmiş ödül kazananları.
class DailyMiniRewardsScreen extends StatefulWidget {
  const DailyMiniRewardsScreen({super.key});

  @override
  State<DailyMiniRewardsScreen> createState() => _DailyMiniRewardsScreenState();
}

class _DailyMiniRewardsScreenState extends State<DailyMiniRewardsScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.haftalik;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(DailyMiniRankingService.instance.refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DailyMiniRankingService.instance,
      builder: (context, _) {
        final service = DailyMiniRankingService.instance;
        final snap = service.snapshotFor(_period);
        final history = service.history;

        return Scaffold(
          backgroundColor: AppTheme.ink,
          appBar: AppBar(
            backgroundColor: AppTheme.ink,
            foregroundColor: Colors.white,
            leading: const AppBackButton(),
            title: const Text(
              'ÖDÜL · Sıralama',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: service.loading && snap == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.champagne),
                )
              : RefreshIndicator(
                  color: AppTheme.champagne,
                  onRefresh: () => service.refresh(force: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _RewardBanner(
                        rewardDays:
                            snap?.rewardDays ?? const {1: 3, 2: 2, 3: 1},
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<LeaderboardPeriod>(
                        segments: const [
                          ButtonSegment(
                            value: LeaderboardPeriod.haftalik,
                            label: Text('Haftalık'),
                          ),
                          ButtonSegment(
                            value: LeaderboardPeriod.aylik,
                            label: Text('Aylık'),
                          ),
                        ],
                        selected: {_period},
                        onSelectionChanged: (s) =>
                            setState(() => _period = s.first),
                      ),
                      if (snap != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _periodLabel(snap.periodStart, snap.periodEnd),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        if (snap.myRank != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Sen: ${snap.myRank}. · ${snap.myTotalCorrect} doğru · '
                            '${formatExamDuration(snap.myTotalDurationSeconds)}',
                            style: const TextStyle(
                              color: AppTheme.champagneLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (snap.leaderboard.isEmpty)
                          Text(
                            'Bu dönemde henüz sıralama yok.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          )
                        else
                          ...snap.leaderboard.map(
                            (row) => _PeriodRow(
                              row: row,
                              rewardDays: snap.rewardDays,
                            ),
                          ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'GEÇMİŞ KAZANANLAR',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.champagne.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (history == null || history.periods.isEmpty)
                        Text(
                          'Henüz finalize edilmiş dönem yok.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        )
                      else
                        ...history.periods.map(_HistoryPeriodCard.new),
                    ],
                  ),
                ),
        );
      },
    );
  }

  String _periodLabel(String start, String end) {
    if (start.isEmpty || end.isEmpty) return '';
    return '$start – $end';
  }
}

class _RewardBanner extends StatelessWidget {
  final Map<int, int> rewardDays;

  const _RewardBanner({required this.rewardDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.champagne.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          colors: [
            AppTheme.champagne.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium ödülleri',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Toplam doğru · eşitlikte toplam süre. '
            '1. → ${rewardDays[1] ?? 3} gün · 2. → ${rewardDays[2] ?? 2} gün · '
            '3. → ${rewardDays[3] ?? 1} gün',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final PeriodLeaderRow row;
  final Map<int, int> rewardDays;

  const _PeriodRow({required this.row, required this.rewardDays});

  @override
  Widget build(BuildContext context) {
    final reward = rewardDays[row.rank];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: row.rank <= 3 ? 0.08 : 0.04),
        border: Border.all(
          color: row.rank <= 3
              ? AppTheme.champagne.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${row.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: row.rank <= 3 ? AppTheme.champagne : Colors.white70,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  FrostedEmail(
                    prefix: row.emailPrefix,
                    rest: row.emailRest,
                    style: const TextStyle(color: Colors.white),
                  ),
                Text(
                  '${row.totalCorrect} doğru · ${formatExamDuration(row.totalDurationSeconds)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (reward != null)
            Text(
              '+$reward g',
              style: const TextStyle(
                color: AppTheme.champagneLight,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryPeriodCard extends StatelessWidget {
  final RewardHistoryPeriod period;

  const _HistoryPeriodCard(this.period);

  @override
  Widget build(BuildContext context) {
    final label = period.periodKind == RankingPeriodKind.weekly
        ? 'Haftalık'
        : 'Aylık';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label · ${period.periodStart} – ${period.periodEnd}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          for (final w in period.winners)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '#${w.rank} ${w.displayName.isNotEmpty ? w.displayName : '${w.emailPrefix}${w.emailRest}'} '
                '· ${w.totalCorrect} doğru · +${w.premiumDays} gün Premium',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
