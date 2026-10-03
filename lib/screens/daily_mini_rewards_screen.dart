import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_mini_ranking_models.dart';
import '../models/leaderboard_model.dart';
import '../services/daily_mini_ranking_service.dart';
import '../theme/app_theme.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/app_back_button.dart';
import '../widgets/frosted_email.dart';
import '../constants/daily_mini_exam_constants.dart';

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
        final odulActive = service.rewardsVisible;

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
                _PremiumAppBar(odulActive: odulActive),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.champagne,
                    backgroundColor: AppTheme.inkSoft,
                    onRefresh: () => service.refresh(force: true),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                      children: [
                        if (odulActive) ...[
                          _RewardHero(rewardDays: rewards),
                          const SizedBox(height: 18),
                        ],
                        _SeninSiranButton(
                          myRank: snap?.myRank,
                          myCorrect: snap?.myTotalCorrect ?? 0,
                          myDuration: snap?.myTotalDurationSeconds ?? 0,
                          loading: service.loading && snap == null,
                        ),
                        const SizedBox(height: 12),
                        _PeriodTabs(
                          period: _period,
                          onChanged: (p) => setState(() => _period = p),
                        ),
                        if (service.loading && snap == null) ...[
                          const SizedBox(height: 28),
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(
                                color: AppTheme.champagne,
                              ),
                            ),
                          ),
                        ] else if (snap != null) ...[
                          if (snap.periodStart.isNotEmpty &&
                              snap.periodEnd.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _PeriodDateLabel(
                              label: _periodLabel(
                                snap.periodStart,
                                snap.periodEnd,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (snap.leaderboard.isEmpty)
                            const _EmptyHint(
                              'Sınava Girmedin!',
                            )
                          else
                            ...snap.leaderboard.map(
                              (row) => _PeriodRow(
                                row: row,
                                rewardDays: rewards,
                                isMe: snap.myRank == row.rank,
                                showRewards: odulActive,
                              ),
                            ),
                        ],
                        if (odulActive) ...[
                          const SizedBox(height: 28),
                          const _SectionEyebrow('Geçmiş kazananlar'),
                          const SizedBox(height: 12),
                          if (service.loading && history == null)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppTheme.champagne,
                                  ),
                                ),
                              ),
                            )
                          else if (history == null || history.periods.isEmpty)
                            const _EmptyHint(
                              'Henüz finalize edilmiş dönem yok.',
                            )
                          else
                            ...history.periods.map(_HistoryPeriodCard.new),
                        ],
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
    return formatTurkishPeriodRange(start, end);
  }
}

class _PremiumAppBar extends StatelessWidget {
  final bool odulActive;

  const _PremiumAppBar({required this.odulActive});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 12, 8),
      child: Row(
        children: [
          const AppBackButton(),
          Expanded(
            child: Text(
              odulActive ? 'ÖDÜL · Sıralama' : 'SIRALAMA',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppTheme.champagneLight,
              ),
            ),
          ),
          // AppBackButton (IconButton) ile denge — sağda ÖDÜL yok.
          const SizedBox(width: 48),
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
            DailyMiniExamConstants.tieBreakCopy,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 10,
                child: _MedalChip(
                  place: 2,
                  label: '${rewardDays[2] ?? 2} gün Premium',
                  tone: _MedalTone.silver,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 11,
                child: _MedalChip(
                  place: 1,
                  label: '${rewardDays[1] ?? 3} gün Premium',
                  tone: _MedalTone.gold,
                  featured: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: _MedalChip(
                  place: 3,
                  label: '${rewardDays[3] ?? 1} gün Premium',
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
  final int place;
  final String label;
  final _MedalTone tone;
  final bool featured;

  const _MedalChip({
    required this.place,
    required this.label,
    required this.tone,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      _MedalTone.gold => const [
          Color(0xFFFFF8EE),
          Color(0xFFF3E2B8),
          Color(0xFFE8C878),
          Color(0xFFB8860B),
        ],
      _MedalTone.silver => const [
          Color(0xFFF7FAFC),
          Color(0xFFE2E8F0),
          Color(0xFFA8B4C4),
          Color(0xFF64748B),
        ],
      _MedalTone.bronze => const [
          Color(0xFFFFF1E6),
          Color(0xFFF0D4B8),
          Color(0xFFC4895A),
          Color(0xFF8B5A2B),
        ],
    };
    final icon = switch (place) {
      1 => Icons.emoji_events_rounded,
      2 => Icons.military_tech_rounded,
      _ => Icons.workspace_premium_rounded,
    };
    final padV = featured ? 14.0 : 10.0;

    return Container(
      padding: EdgeInsets.fromLTRB(8, padV, 8, padV - 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(featured ? 16 : 13),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[0].withValues(alpha: 0.22),
            colors[2].withValues(alpha: 0.14),
            Colors.black.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(
          color: colors[2].withValues(alpha: featured ? 0.9 : 0.65),
          width: featured ? 1.6 : 1.15,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[2].withValues(alpha: featured ? 0.42 : 0.22),
            blurRadius: featured ? 18 : 10,
            offset: const Offset(0, 5),
          ),
          if (featured)
            BoxShadow(
              color: colors[0].withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: featured ? 42 : 34,
            height: featured ? 42 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[2].withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: featured ? 22 : 17,
              color: AppTheme.ink,
            ),
          ),
          SizedBox(height: featured ? 8 : 6),
          Text(
            '$place.',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: featured ? 22 : 16,
              fontWeight: FontWeight.w900,
              height: 1,
              color: colors[0],
              shadows: [
                Shadow(
                  color: colors[2].withValues(alpha: 0.55),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: featured ? 11 : 10,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: colors[0].withValues(alpha: 0.95),
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
    return Row(
      children: [
        Expanded(
          child: _PeriodTab(
            label: 'Haftalık',
            icon: Icons.calendar_view_week_rounded,
            selected: period == LeaderboardPeriod.haftalik,
            onTap: () => onChanged(LeaderboardPeriod.haftalik),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PeriodTab(
            label: 'Aylık',
            icon: Icons.calendar_month_rounded,
            selected: period == LeaderboardPeriod.aylik,
            onTap: () => onChanged(LeaderboardPeriod.aylik),
          ),
        ),
      ],
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF8EE),
                      Color(0xFFF3E2B8),
                      AppTheme.champagne,
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                  ),
            border: Border.all(
              color: selected
                  ? const Color(0xFFD4AF6A)
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.35 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppTheme.ink
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.15,
                  color: selected
                      ? AppTheme.ink
                      : Colors.white.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodDateLabel extends StatelessWidget {
  final String label;

  const _PeriodDateLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
  }
}

/// Premium glass CTA — haftalık/aylık sekmelerinin üstünde "Senin sıran".
class _SeninSiranButton extends StatelessWidget {
  final int? myRank;
  final int myCorrect;
  final int myDuration;
  final bool loading;

  const _SeninSiranButton({
    required this.myRank,
    required this.myCorrect,
    required this.myDuration,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasRank = myRank != null && myRank! > 0;
    final statsText = loading
        ? 'Sıralaman yükleniyor…'
        : hasRank
            ? '$myCorrect doğru · ${formatExamDuration(myDuration)}'
            : 'Sınava Girmedin!';
    final maxW = MediaQuery.sizeOf(context).width * 0.76;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasRank || loading
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sınava Girmedin!',
                        ),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.inkSoft.withValues(alpha: 0.98),
                    AppTheme.ink.withValues(alpha: 0.92),
                    const Color(0xFF101826),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'SENİN SIRAN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: AppTheme.champagneLight.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: AppTheme.champagne.withValues(alpha: 0.7),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.champagne.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.champagneLight,
                            ),
                          )
                        : Text(
                            hasRank ? '#$myRank' : '—',
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.champagneLight,
                            ),
                          ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    statsText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SIRALAMA SÜREKLİ GÜNCELLENMEKTEDİR',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.55,
                      height: 1.15,
                      color: AppTheme.champagne.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final PeriodLeaderRow row;
  final Map<int, int> rewardDays;
  final bool isMe;
  final bool showRewards;

  const _PeriodRow({
    required this.row,
    required this.rewardDays,
    required this.isMe,
    this.showRewards = true,
  });

  @override
  Widget build(BuildContext context) {
    final reward = showRewards ? rewardDays[row.rank] : null;
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
            '$label · ${formatTurkishPeriodRange(period.periodStart, period.periodEnd)}',
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
