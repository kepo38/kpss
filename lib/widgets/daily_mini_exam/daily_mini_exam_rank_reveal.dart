import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/daily_mini_exam_models.dart';
import '../../services/auth_service.dart';
import '../../services/daily_mini_exam_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/daily_mini_exam_logic.dart';
import '../mini_confetti_burst.dart';

class DailyMiniExamRankReveal extends StatefulWidget {
  static const countdownSeconds = 10;

  final int? rank;
  final int participantCount;
  final List<DailyMiniLeaderRow> leaders;
  final DailyMiniRankTrend trend;

  const DailyMiniExamRankReveal({
    super.key,
    required this.rank,
    required this.participantCount,
    required this.leaders,
    required this.trend,
  });

  @override
  State<DailyMiniExamRankReveal> createState() =>
      _DailyMiniExamRankRevealState();
}

class _DailyMiniExamRankRevealState extends State<DailyMiniExamRankReveal>
    with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _rankPoll;
  bool _celebrateRank = false;
  bool _awaitingRankAfterCountdown = false;
  bool _countdownDone = false;
  int _secondsLeft = DailyMiniExamRankReveal.countdownSeconds;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;

  DailyMiniExamService get _service => DailyMiniExamService.instance;

  /// Servis bayrağı + yerel 10 sn: panel görünür görünmez sayaç başlar.
  bool get _showCountdown =>
      _service.rankRevealActive && !_countdownDone;

  int? get _resolvedRank {
    if (_showCountdown) return null;
    if (widget.rank != null && widget.rank! > 0) return widget.rank;
    final attemptRank = _service.attempt?.rank;
    if (attemptRank != null && attemptRank > 0) return attemptRank;
    final userId = AuthService.instance.user?.id;
    if (userId == null) return null;
    for (final row in widget.leaders) {
      if (row.userId == userId && row.rank > 0) return row.rank;
    }
    return null;
  }

  bool get _hasRank {
    final rank = _resolvedRank;
    return rank != null && rank > 0;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _service.addListener(_onServiceChanged);
    _bootstrapCountdown();
    _syncPulse();
    _ensureTimer();
  }

  void _bootstrapCountdown() {
    if (!_service.rankRevealActive || _countdownDone) return;
    // Panel görünür görünmez 10 sn yerelden başlar (ağ gecikmesi yemez).
    _secondsLeft = DailyMiniExamRankReveal.countdownSeconds;
  }

  void _onServiceChanged() {
    // Yeni bitirme: servis tekrar armed olduysa yerel sayacı yeniden kur.
    if (_service.rankRevealActive && _countdownDone) {
      _countdownDone = false;
      _secondsLeft = DailyMiniExamRankReveal.countdownSeconds;
      _celebrateRank = false;
    } else if (_service.rankRevealActive &&
        !_countdownDone &&
        _timer == null &&
        _secondsLeft <= 0) {
      _secondsLeft = DailyMiniExamRankReveal.countdownSeconds;
    }
    _syncPulse();
    _ensureTimer();
    if (mounted) setState(() {});
  }

  void _syncPulse() {
    if (_showCountdown && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
      _shimmerCtrl.repeat();
    } else if (!_showCountdown) {
      if (_pulseCtrl.isAnimating) {
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
      }
      if (_shimmerCtrl.isAnimating) {
        _shimmerCtrl.stop();
        _shimmerCtrl.value = 0;
      }
    }
  }

  void _ensureTimer() {
    if (_showCountdown && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!_showCountdown && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _ensureRankPoll() {
    if (!_awaitingRankAfterCountdown || _showCountdown || _hasRank) {
      _rankPoll?.cancel();
      _rankPoll = null;
      return;
    }
    if (_rankPoll != null) return;
    _rankPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_awaitingRankAfterCountdown || _showCountdown) {
        return;
      }
      if (_hasRank) {
        _awaitingRankAfterCountdown = false;
        _triggerRankCelebration();
        setState(() {});
        _rankPoll?.cancel();
        _rankPoll = null;
        return;
      }
      await _service.refresh();
      if (!mounted || !_awaitingRankAfterCountdown) return;
      if (_hasRank) {
        _awaitingRankAfterCountdown = false;
        _triggerRankCelebration();
        setState(() {});
        _rankPoll?.cancel();
        _rankPoll = null;
      }
    });
  }

  void _triggerRankCelebration() {
    if (_service.rankRevealCelebrated || !_hasRank) return;
    unawaited(_service.markRankRevealCelebrated());
    if (!mounted) return;
    setState(() => _celebrateRank = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rankPoll?.cancel();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  Future<void> _tick() async {
    if (!mounted || !_showCountdown) return;
    if (_secondsLeft <= 1) {
      _secondsLeft = 0;
      _countdownDone = true;
      _timer?.cancel();
      _timer = null;
      _service.clearRankReveal();
      _awaitingRankAfterCountdown = true;
      if (_hasRank) {
        _awaitingRankAfterCountdown = false;
        _triggerRankCelebration();
      } else {
        _ensureRankPoll();
        unawaited(_service.refresh().then((_) {
          if (!mounted || !_awaitingRankAfterCountdown) return;
          if (_hasRank) {
            _awaitingRankAfterCountdown = false;
            _triggerRankCelebration();
          }
          setState(() {});
        }));
      }
    } else {
      _secondsLeft -= 1;
      _service.tickRankRevealCountdown();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rank = _resolvedRank;
    final showRank = _hasRank;
    final countdownActive = _showCountdown;
    final glowAlpha = countdownActive
        ? 0.28 + (_pulseCtrl.value * 0.22)
        : (showRank ? 0.38 : 0.22);

    return MiniConfettiBurst(
      trigger: _celebrateRank,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _shimmerCtrl]),
        builder: (context, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: countdownActive
                    ? [
                        Color.lerp(
                          const Color(0xFFFFEDB0),
                          const Color(0xFFFFF4D4),
                          _pulseCtrl.value,
                        )!,
                        const Color(0xFFF5DC98),
                        Color.lerp(
                          AppTheme.champagne,
                          const Color(0xFFFFE8A8),
                          _pulseCtrl.value * 0.6,
                        )!,
                      ]
                    : showRank
                        ? const [
                            Color(0xFFFFEDB0),
                            Color(0xFFF5DC98),
                            Color(0xFFE8C878),
                            AppTheme.champagne,
                          ]
                        : const [
                            Color(0xFFFFEDB0),
                            Color(0xFFE8C878),
                            AppTheme.champagne,
                          ],
              ),
              border: Border.all(
                color: countdownActive
                    ? Color.lerp(
                        const Color(0xFFFFE5A0),
                        Colors.white.withValues(alpha: 0.92),
                        _pulseCtrl.value * 0.55,
                      )!
                    : const Color(0xFFFFE5A0)
                        .withValues(alpha: showRank ? 1 : 0.8),
                width: countdownActive ? 1.45 : (showRank ? 1.35 : 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGold.withValues(alpha: glowAlpha),
                  blurRadius: countdownActive ? 18 + (_pulseCtrl.value * 6) : 10,
                  spreadRadius: countdownActive ? _pulseCtrl.value * 1.2 : 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 460),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.14),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: countdownActive
                    ? _HeyecanDoruktaLabel(
                        key: ValueKey('excitement-$_secondsLeft'),
                        pulse: _pulseCtrl,
                        shimmer: _shimmerCtrl,
                        secondsLeft: _secondsLeft,
                      )
                    : const Text(
                        key: ValueKey('rank-label'),
                        'BUGÜNKÜ SIRALAMAN',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.35,
                          color: AppTheme.ink,
                          height: 1.15,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            _RankRevealSlot(
              showCountdown: countdownActive,
              secondsLeft: _secondsLeft,
              totalSeconds: DailyMiniExamRankReveal.countdownSeconds,
              rank: showRank ? rank : null,
              trend: widget.trend,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeyecanDoruktaLabel extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> shimmer;
  final int secondsLeft;

  const _HeyecanDoruktaLabel({
    super.key,
    required this.pulse,
    required this.shimmer,
    required this.secondsLeft,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, shimmer]),
      builder: (context, _) {
        final scale = 1.0 + pulse.value * 0.025;
        final highlight = 0.28 + shimmer.value * 0.22;
        final showSubtitle = secondsLeft <= 4;

        return Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Heyecan Dorukta!',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  height: 1.15,
                  color: AppTheme.ink,
                  shadows: [
                    Shadow(
                      color: Colors.white.withValues(alpha: highlight),
                      offset: const Offset(0, 1),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                child: showSubtitle
                    ? Padding(
                        key: const ValueKey('iste-siralaman'),
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'İŞTE SIRALAMAN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                            height: 1.1,
                            color: AppTheme.ink.withValues(alpha: 0.62),
                          ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('iste-siralaman-hidden'),
                        height: 0,
                        width: 0,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RankRevealSlot extends StatelessWidget {
  final bool showCountdown;
  final int secondsLeft;
  final int totalSeconds;
  final int? rank;
  final DailyMiniRankTrend trend;

  const _RankRevealSlot({
    required this.showCountdown,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.rank,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: showCountdown
            ? _PremiumRankCountdown(
                key: const ValueKey('countdown'),
                secondsLeft: secondsLeft,
                totalSeconds: totalSeconds,
              )
            : rank != null
                ? _RankNumberBadge(
                    key: ValueKey('rank-$rank'),
                    rank: rank!,
                    trend: trend,
                  )
                : const _RankPendingDot(key: ValueKey('pending')),
      ),
    );
  }
}

class _RankNumberBadge extends StatelessWidget {
  final int rank;
  final DailyMiniRankTrend trend;

  const _RankNumberBadge({
    super.key,
    required this.rank,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8EE),
            Color(0xFFF0E0BC),
          ],
        ),
        border: Border.all(
          color: AppTheme.ink.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonGold.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            formatTrInt(rank),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontFamily: 'serif',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
              color: AppTheme.ink,
            ),
          ),
          if (trend == DailyMiniRankTrend.improved)
            const Positioned(
              right: 2,
              top: 2,
              child: Icon(
                Icons.arrow_drop_up_rounded,
                size: 16,
                color: Color(0xFF145A20),
              ),
            )
          else if (trend == DailyMiniRankTrend.worsened)
            const Positioned(
              right: 2,
              top: 2,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: Color(0xFF8E0000),
              ),
            ),
        ],
      ),
    );
  }
}

class _RankPendingDot extends StatelessWidget {
  const _RankPendingDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.ink.withValues(alpha: 0.06),
        border: Border.all(
          color: AppTheme.ink.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        '…',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1,
          color: AppTheme.ink.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _PremiumRankCountdown extends StatefulWidget {
  final int secondsLeft;
  final int totalSeconds;

  const _PremiumRankCountdown({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
  });

  @override
  State<_PremiumRankCountdown> createState() => _PremiumRankCountdownState();
}

class _PremiumRankCountdownState extends State<_PremiumRankCountdown>
    with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final AnimationController _tickCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void didUpdateWidget(covariant _PremiumRankCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.secondsLeft != widget.secondsLeft) {
      _tickCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _tickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.secondsLeft / widget.totalSeconds;
    final urgent = widget.secondsLeft <= 3;

    return AnimatedBuilder(
      animation: Listenable.merge([_ringCtrl, _tickCtrl]),
      builder: (context, child) {
        final tickScale = 1.0 + (1 - _tickCtrl.value) * (urgent ? 0.14 : 0.08);
        final ringTurn = _ringCtrl.value * 2 * 3.1415926535;

        return Transform.scale(
          scale: tickScale,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGold.withValues(
                    alpha: urgent ? 0.55 : 0.32,
                  ),
                  blurRadius: urgent ? 14 : 8,
                  spreadRadius: urgent ? 1.2 : 0,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: ringTurn,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFFF8EE),
                          Color(0xFFE8C878),
                          AppTheme.champagne,
                          Color(0xFFFFF8EE),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.72),
                        AppTheme.ink.withValues(alpha: 0.06),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.ink.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          strokeWidth: 2.4,
                          backgroundColor: AppTheme.ink.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            urgent
                                ? const Color(0xFF8E0000)
                                : AppTheme.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.secondsLeft}',
                        style: TextStyle(
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                          fontFamily: 'serif',
                          fontSize: urgent ? 16 : 15,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          color: urgent
                              ? const Color(0xFF8E0000)
                              : AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
