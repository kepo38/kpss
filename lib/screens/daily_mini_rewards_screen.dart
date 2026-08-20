import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_mini_ranking_models.dart';
import '../models/leaderboard_model.dart';
import '../services/daily_mini_ranking_service.dart';
import '../theme/app_theme.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/app_back_button.dart';
import '../widgets/daily_mini_exam/daily_mini_odul_button.dart';
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
        final rewards = snap?.rewardDays ?? const {1: 3, 2: 2, 3: 1};

        return Scaffold(
          backgroundColor: AppTheme.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A2438),
                  AppTheme.ink,
                  Color(0xFF090E18),
                ],
                stops: [0, 0.35, 1],
              ),
            ),
            child: Column(
              children: [
                _PremiumAppBar(
                  onOdul: () => showDailyMiniOdulInfoCard(context),
                ),
                Expanded(
                  child: service.loading && snap == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.champagne,
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.champagne,
                          backgroundColor: AppTheme.inkSoft,
                          onRefresh: () => service.refresh(force: true),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                            children: [
                              _RewardHero(rewardDays: rewards),
                              const SizedBox(height: 18),
                              _PeriodTabs(
                                period: _period,
                                onChanged: (p) => setState(() => _period = p),
                              ),
                              if (snap != null) ...[
                                const SizedBox(height: 14),
                                _PeriodMeta(
                                  label: _periodLabel(
                                    snap.periodStart,
                                    snap.periodEnd,
                                  ),
                                  myRank: snap.myRank,
                                  myCorrect: snap.myTotalCorrect,
                                  myDuration: snap.myTotalDurationSeconds,
                                ),
                                const SizedBox(height: 14),
                                if (snap.leaderboard.isEmpty)
                                  const _EmptyHint(
                                    'Bu dönemde henüz sıralama yok.',
                                  )
                                else
                                  ...snap.leaderboard.map(
                                    (row) => _PeriodRow(
                                      row: row,
                                      rewardDays: rewards,
                                      isMe: snap.myRank == row.rank,
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 28),
                              const _SectionEyebrow('Geçmiş kazananlar'),
                              const SizedBox(height: 12),
                              if (history == null || history.periods.isEmpty)
                                const _EmptyHint(
                                  'Henüz finalize edilmiş dönem yok.',
                                )
                              else
                                ...history.periods.map(_HistoryPeriodCard.new),
                            ],
                          ),
                        ),
                ),
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

class _PremiumAppBar extends StatelessWidget {
  final VoidCallback onOdul;

  const _PremiumAppBar({required this.onOdul});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 12, 8),
      child: Row(
        children: [
          const AppBackButton(),
          const Expanded(
            child: Text(
              'ÖDÜL · Sıralama',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppTheme.champagneLight,
              ),
            ),
          ),
          DailyMiniOdulButton(size: 42, onPressed: onOdul),
        ],
      ),
    );
  }
}

class _RewardHero extends StatelessWidget {
  final Map<int, int> rewardDays;

  const _RewardHero({required this.rewardDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.45),
          width: 1.2,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3D3218),
            Color(0xFF1E283C),
            Color(0xFF121826),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF1D0), AppTheme.champagne],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppTheme.ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREMIUM YARIŞMA',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.champagne,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'İlk 3 Premium kazanır',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Toplam doğru · eşitlikte daha kısa süre önde.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MedalChip(
                  place: '1.',
                  label: '${rewardDays[1] ?? 3} gün',
                  tone: _MedalTone.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MedalChip(
                  place: '2.',
                  label: '${rewardDays[2] ?? 2} gün',
                  tone: _MedalTone.silver,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MedalChip(
                  place: '3.',
                  label: '${rewardDays[3] ?? 1} gün',
                  tone: _MedalTone.bronze,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MedalTone { gold, silver, bronze }

class _MedalChip extends StatelessWidget {
  final String place;
  final String label;
  final _MedalTone tone;

  const _MedalChip({
    required this.place,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _MedalTone.gold => const [Color(0xFFFFF1D0), Color(0xFFE8C878)],
      _MedalTone.silver => const [Color(0xFFE8EEF5), Color(0xFFA8B4C4)],
      _MedalTone.bronze => const [Color(0xFFF0D4B8), Color(0xFFC4895A)],
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.22),
        border: Border.all(color: colors.last.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Text(
            place,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.first,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.first.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod> onChanged;

  const _PeriodTabs({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PeriodTab(
              label: 'Haftalık',
              selected: period == LeaderboardPeriod.haftalik,
              onTap: () => onChanged(LeaderboardPeriod.haftalik),
            ),
          ),
          Expanded(
            child: _PeriodTab(
              label: 'Aylık',
              selected: period == LeaderboardPeriod.aylik,
              onTap: () => onChanged(LeaderboardPeriod.aylik),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFFFF4DE), AppTheme.champagne],
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: selected
                  ? AppTheme.ink
                  : Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodMeta extends StatelessWidget {
  final String label;
  final int? myRank;
  final int myCorrect;
  final int myDuration;

  const _PeriodMeta({
    required this.label,
    required this.myRank,
    required this.myCorrect,
    required this.myDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        if (myRank != null) ...[
          if (label.isNotEmpty) const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.4),
              ),
              gradient: LinearGradient(
                colors: [
                  AppTheme.champagne.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.ink.withValues(alpha: 0.45),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    '$myRank',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w800,
                      color: AppTheme.champagneLight,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Senin sıran',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppTheme.champagne,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$myCorrect doğru · ${formatExamDuration(myDuration)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final PeriodLeaderRow row;
  final Map<int, int> rewardDays;
  final bool isMe;

  const _PeriodRow({
    required this.row,
    required this.rewardDays,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final reward = rewardDays[row.rank];
    final podium = row.rank <= 3;
    final medal = switch (row.rank) {
      1 => const Color(0xFFE8C878),
      2 => const Color(0xFFC0CAD6),
      3 => const Color(0xFFC4895A),
      _ => Colors.white24,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: podium
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  medal.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.04),
                ],
              )
            : null,
        color: podium ? null : Colors.white.withValues(alpha: isMe ? 0.07 : 0.035),
        border: Border.all(
          color: isMe
              ? AppTheme.champagne.withValues(alpha: 0.55)
              : podium
                  ? medal.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.08),
          width: isMe || podium ? 1.2 : 1,
        ),
        boxShadow: podium
            ? [
                BoxShadow(
                  color: medal.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: podium
                  ? medal.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: podium
                    ? medal.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              '${row.rank}',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: podium ? medal : Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: row.displayName.isNotEmpty
                          ? Text(
                              row.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            )
                          : FrostedEmail(
                              prefix: row.emailPrefix,
                              rest: row.emailRest,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppTheme.champagne.withValues(alpha: 0.2),
                        ),
                        child: const Text(
                          'SEN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF4DE), AppTheme.champagne],
                ),
              ),
              child: Text(
                '+$reward gün',
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  final String text;

  const _SectionEyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w800,
        color: AppTheme.champagne.withValues(alpha: 0.9),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.48),
          height: 1.35,
        ),
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
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label · ${period.periodStart} – ${period.periodEnd}',
            style: const TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          for (final w in period.winners)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${w.rank}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: w.rank <= 3
                            ? AppTheme.champagneLight
                            : Colors.white54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      w.displayName.isNotEmpty
                          ? w.displayName
                          : '${w.emailPrefix}${w.emailRest}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  Text(
                    '+${w.premiumDays} gün',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.champagneLight,
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
