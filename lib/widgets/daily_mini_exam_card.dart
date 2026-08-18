import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/daily_mini_exam_constants.dart';
import '../models/daily_mini_exam_models.dart';
import '../models/quiz_result.dart';
import '../screens/daily_mini_exam_result_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/quiz_screen.dart';
import '../services/ad_manager.dart';
import '../services/auth_service.dart';
import '../services/daily_mini_exam_service.dart';
import '../theme/app_theme.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/countdown_widget.dart';
import 'mini_confetti_burst.dart';
import 'scale_button.dart';

/// Ana sayfa kahraman kartı — günün 20 soruluk ücretsiz mini denemesi.
class DailyMiniExamCard extends StatefulWidget {
  final KpssType kpssType;

  const DailyMiniExamCard({
    super.key,
    required this.kpssType,
  });

  @override
  State<DailyMiniExamCard> createState() => _DailyMiniExamCardState();
}

class _DailyMiniExamCardState extends State<DailyMiniExamCard>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Timer? _rankPoll;
  late DailyMiniExamWindow _window;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _window = DailyMiniExamWindow.from(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _window = DailyMiniExamWindow.from(DateTime.now()));
    });
    _rankPoll = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      if (DailyMiniExamService.instance.hasSubmittedRanking) {
        unawaited(DailyMiniExamService.instance.refresh());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        DailyMiniExamService.instance.setKpssType(widget.kpssType),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DailyMiniExamService.instance.hasSubmittedRanking) {
      unawaited(DailyMiniExamService.instance.refresh());
    }
  }

  @override
  void didUpdateWidget(covariant DailyMiniExamCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kpssType != widget.kpssType) {
      unawaited(DailyMiniExamService.instance.setKpssType(widget.kpssType));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _rankPoll?.cancel();
    super.dispose();
  }

  Future<void> _shareRank() async {
    final service = DailyMiniExamService.instance;
    final attempt = service.attempt;
    final rank = attempt?.rank;
    if (attempt == null || rank == null || service.participantCount <= 0) {
      return;
    }
    await Share.share(
      buildDailyMiniShareText(
        rank: rank,
        participantCount: service.participantCount,
        correct: attempt.correct,
        total: attempt.total,
      ),
    );
  }

  Future<void> _openProfileForLogin() async {
    final user = AuthService.instance.user;
    if (user == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Misafir yalnızca ilk gün katılabilir. Profil’den Google ile giriş yapın.',
        ),
      ),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(user: user),
      ),
    );
  }

  Future<void> _openResult() async {
    final service = DailyMiniExamService.instance;
    final attempt = service.attempt;
    if (attempt == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DailyMiniExamResultScreen(),
      ),
    );
  }

  Future<void> _startOrResume() async {
    final service = DailyMiniExamService.instance;
    if (service.guestMustSignIn) {
      await _openProfileForLogin();
      return;
    }
    if (!_window.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Yeni mini deneme her gün ${DailyMiniExamConstants.opensClock}’de açılır.',
          ),
        ),
      );
      return;
    }
    final questions = await service.fetchQuestionsForToday();
    if (!mounted) return;
    if (questions.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bugün için yeterli soru henüz yayınlanmadı.'),
        ),
      );
      return;
    }

    final remainingMinutes = _window.remaining.inMinutes.clamp(1, 20);
    AdManager.instance.skipNextPageTransition();
    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(
          title: DailyMiniExamConstants.title,
          questions: questions,
          timeLimitMinutes: remainingMinutes,
          initialIndex: service.canResumeQuiz ? service.currentIndex : 0,
          initialAnswers: service.canResumeQuiz ? service.answers : null,
          initialElapsed: Duration(
            seconds: service.canResumeQuiz ? service.elapsedSeconds : 0,
          ),
          skipResultDialog: true,
          adFreeExperience: true,
          dailyMiniRankingMode: true,
          onProgress: ({
            required answers,
            required currentIndex,
            required elapsed,
          }) {
            return service.saveProgress(
              answers: answers,
              currentIndex: currentIndex,
              elapsed: elapsed,
            );
          },
        ),
      ),
    );
    if (result == null) return;

    if (result.submitDailyMiniRanking ||
        (result.completed && !service.rankingLocked)) {
      await service.finalizeRanking(
        result: result,
        answers: result.selectedAnswers,
      );
      return;
    } else if (result.completed && service.rankingLocked) {
      await service.saveProgress(
        answers: result.selectedAnswers,
        currentIndex: result.selectedAnswers.length - 1,
        elapsed: result.duration,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        DailyMiniExamService.instance,
        AuthService.instance,
      ]),
      builder: (context, _) {
        final service = DailyMiniExamService.instance;
        final attempt = service.attempt;
        final submittedRanking = service.hasSubmittedRanking;
        final guestMustSignIn = service.guestMustSignIn;
        final ctaLabel = guestMustSignIn
            ? DailyMiniExamConstants.ctaGuestSignIn
            : (service.rankingLocked
                ? DailyMiniExamConstants.ctaResume
                : (service.hasInProgress
                    ? DailyMiniExamConstants.ctaResume
                    : (_window.isOpen
                        ? DailyMiniExamConstants.ctaStart
                        : '${DailyMiniExamConstants.opensClock}’de açılır')));
        final rank = attempt?.rank;
        final dark = AppTheme.isDark(context);

        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: dark ? 0.22 : 0.18),
                  blurRadius: dark ? 28 : 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: dark ? 0.35 : 0.06),
                  blurRadius: dark ? 18 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              clipBehavior: Clip.none,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: dark
                        ? AppTheme.champagneLight.withValues(alpha: 0.38)
                        : AppTheme.champagne.withValues(alpha: 0.42),
                    width: 1.15,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [
                            Color(0xFF1C2A44),
                            Color(0xFF162338),
                            Color(0xFF121C30),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.98),
                            AppTheme.creamTop,
                            AppTheme.champagne.withValues(alpha: 0.14),
                          ],
                    stops: dark ? const [0, 0.45, 1] : const [0, 0.55, 1],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: dark
                                  ? [
                                      AppTheme.champagne.withValues(alpha: 0.12),
                                      AppTheme.champagne.withValues(alpha: 0.02),
                                      Colors.transparent,
                                    ]
                                  : [
                                      AppTheme.champagne.withValues(alpha: 0.05),
                                      Colors.transparent,
                                      Colors.transparent,
                                    ],
                              stops: const [0, 0.22, 0.55],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 3,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF3E2B8),
                              AppTheme.champagneLight,
                              AppTheme.champagne,
                              Color(0xFF8F6E32),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -40,
                      top: -48,
                      child: IgnorePointer(
                        child: Container(
                          width: 168,
                          height: 168,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.neonGold.withValues(alpha: 0.22),
                                AppTheme.champagne.withValues(alpha: 0.08),
                                AppTheme.champagne.withValues(alpha: 0),
                              ],
                              stops: const [0, 0.42, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 28,
                      bottom: -56,
                      child: IgnorePointer(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.champagne.withValues(alpha: 0.1),
                                AppTheme.champagne.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _FreeRibbon(dark: dark),
                    ),
                    Positioned(
                      top: 10,
                      right: 12,
                      child: _ClosingTimer(window: _window, dark: dark),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 30, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _CardHeader(),
                          if (!submittedRanking) ...[
                            const SizedBox(height: 10),
                            const _SubjectMix(),
                            if (service.leaderboard.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _LeaderboardPreviewPanel(
                                leaders: service.leaderboard,
                                participantCount: service.participantCount,
                                totalQuestions:
                                    DailyMiniExamConstants.questionCount,
                              ),
                            ],
                            const SizedBox(height: 14),
                            ScaleButton(
                              onPressed: guestMustSignIn
                                  ? _openProfileForLogin
                                  : _startOrResume,
                              child: _StartExamCta(
                                label: ctaLabel,
                                enabled: guestMustSignIn || _window.isOpen,
                              ),
                            ),
                          ] else if (attempt != null) ...[
                            const SizedBox(height: 14),
                            _ScoreBlock(
                              attempt: attempt,
                              onOpen: _openResult,
                            ),
                            const SizedBox(height: 12),
                            _CompletedLeaderboardPanel(
                              rank: rank,
                              participantCount: service.participantCount,
                              leaders: service.leaderboard,
                              totalQuestions:
                                  DailyMiniExamConstants.questionCount,
                              trend: service.rankTrend,
                              onShare: _shareRank,
                              onDetails: _openResult,
                            ),
                            if (service.canResumeQuiz && _window.isOpen) ...[
                              const SizedBox(height: 12),
                              ScaleButton(
                                onPressed: _startOrResume,
                                child: const _StartExamCta(
                                  label: DailyMiniExamConstants.ctaResume,
                                  enabled: true,
                                ),
                              ),
                            ],
                          ] else ...[
                            const SizedBox(height: 14),
                            _CompletedResultPending(
                              onRefresh: () => unawaited(service.refresh()),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader();

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final titleColor = AppTheme.onPage(context);
    final accent = dark ? AppTheme.champagneLight : AppTheme.champagne;

    return Padding(
      padding: const EdgeInsets.only(right: 78),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 2.5,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent,
                  accent.withValues(alpha: 0.45),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              DailyMiniExamConstants.cardHeadline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 16.5,
                height: 1.12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosingTimer extends StatelessWidget {
  final DailyMiniExamWindow window;
  final bool dark;

  const _ClosingTimer({
    required this.window,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = dark
        ? Colors.white.withValues(alpha: 0.72)
        : AppTheme.ink.withValues(alpha: 0.68);
    final timerColor =
        dark ? AppTheme.champagneLight : const Color(0xFF8F6E32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          window.isOpen
              ? 'Kapanış'
              : 'Açılış · ${DailyMiniExamConstants.opensClock}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          formatHms(window.remaining),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontFamily: 'serif',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.4,
            color: timerColor,
          ),
        ),
      ],
    );
  }
}

class _FreeRibbon extends StatelessWidget {
  final bool dark;

  const _FreeRibbon({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: const Offset(0, -1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: dark ? 0.35 : 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: dark ? 0.28 : 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _RibbonPainter(dark: dark),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 11),
              child: Text(
                DailyMiniExamConstants.eyebrow,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  height: 1,
                  color: dark ? AppTheme.ink : const Color(0xFF3D2E14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final bool dark;

  const _RibbonPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 7)
      ..lineTo(size.width * 0.56, size.height - 7)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.44, size.height - 7)
      ..lineTo(0, size.height - 7)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [
                Color(0xFFF3E2B8),
                AppTheme.champagneLight,
                AppTheme.champagne,
              ]
            : const [
                Color(0xFFF7EED8),
                AppTheme.champagneLight,
                Color(0xFFC9A86C),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, fill);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppTheme.champagne.withValues(alpha: dark ? 0.55 : 0.65);
    canvas.drawPath(path, border);

    final shine = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.28 : 0.42),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));
    canvas.drawPath(path, shine);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class _SubjectMix extends StatelessWidget {
  const _SubjectMix();

  static const _subjects = [
    ('Tarih', '5'),
    ('Coğrafya', '5'),
    ('Vatandaşlık', '5'),
    ('Türkçe', '5'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SubjectTile(
                name: _subjects[0].$1,
                count: _subjects[0].$2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SubjectTile(
                name: _subjects[1].$1,
                count: _subjects[1].$2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _SubjectTile(
                name: _subjects[2].$1,
                count: _subjects[2].$2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SubjectTile(
                name: _subjects[3].$1,
                count: _subjects[3].$2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String name;
  final String count;

  const _SubjectTile({
    required this.name,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final titleColor = AppTheme.onPage(context);
    final tileFill = dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.96);
    final tileBorder = dark
        ? AppTheme.champagne.withValues(alpha: 0.24)
        : AppTheme.champagne.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: tileFill,
        border: Border.all(color: tileBorder),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: AppTheme.champagne.withValues(alpha: dark ? 0.16 : 0.14),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: dark ? 0.35 : 0.42),
              ),
            ),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
                color: dark ? AppTheme.champagneLight : const Color(0xFF8F6E32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartExamCta extends StatefulWidget {
  final String label;
  final bool enabled;

  const _StartExamCta({required this.label, required this.enabled});

  @override
  State<_StartExamCta> createState() => _StartExamCtaState();
}

class _StartExamCtaState extends State<_StartExamCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.enabled) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _StartExamCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final disabledFill = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.ink.withValues(alpha: 0.06);
    final disabledText = dark
        ? Colors.white.withValues(alpha: 0.55)
        : AppTheme.slate.withValues(alpha: 0.7);
    const radius = 14.0;

    final body = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius - 1.5),
        gradient: widget.enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3E2B8),
                  AppTheme.champagneLight,
                  AppTheme.champagne,
                ],
              )
            : null,
        color: widget.enabled ? null : disabledFill,
        boxShadow: widget.enabled
            ? [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
                color: widget.enabled ? AppTheme.ink : disabledText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Opacity(
            opacity: widget.enabled ? 1 : 0.45,
            child: const _FormulaCarMark(),
          ),
        ],
      ),
    );

    if (!widget.enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppTheme.hairline(context)),
        ),
        child: body,
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _RunningGoldBorderPainter(
            progress: _ctrl.value,
            radius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.2),
            child: child,
          ),
        );
      },
      child: body,
    );
  }
}

class _RunningGoldBorderPainter extends CustomPainter {
  final double progress;
  final double radius;

  _RunningGoldBorderPainter({
    required this.progress,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.1),
      Radius.circular(radius),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppTheme.champagne.withValues(alpha: 0.38),
    );

    final shader = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: const [
        Color(0x00FFFFFF),
        Color(0x66FFE5A0),
        Color(0xFFFFF8E7),
        Color(0xFFFFFFFF),
        Color(0xFFFFEDB0),
        Color(0xFFE8C878),
        Color(0x44C9A86C),
        Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.08, 0.14, 0.2, 0.28, 0.36, 0.46, 0.58],
    ).createShader(rect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _RunningGoldBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FormulaCarMark extends StatelessWidget {
  const _FormulaCarMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 34,
      height: 16,
      child: CustomPaint(painter: _FormulaCarPainter()),
    );
  }
}

class _FormulaCarPainter extends CustomPainter {
  const _FormulaCarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()..color = AppTheme.ink;
    final gold = Paint()..color = const Color(0xFF8F6E32);
    final light = Paint()..color = const Color(0xFFFFF6E4);

    final body = Path()
      ..moveTo(size.width * 0.08, size.height * 0.62)
      ..lineTo(size.width * 0.22, size.height * 0.62)
      ..lineTo(size.width * 0.3, size.height * 0.38)
      ..lineTo(size.width * 0.5, size.height * 0.32)
      ..lineTo(size.width * 0.62, size.height * 0.38)
      ..lineTo(size.width * 0.78, size.height * 0.58)
      ..lineTo(size.width * 0.96, size.height * 0.58)
      ..lineTo(size.width * 0.96, size.height * 0.72)
      ..lineTo(size.width * 0.08, size.height * 0.72)
      ..close();
    canvas.drawPath(body, ink);

    final wing = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.02,
        size.height * 0.48,
        size.width * 0.12,
        size.height * 0.16,
      ),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(wing, gold);

    final nose = Path()
      ..moveTo(size.width * 0.78, size.height * 0.6)
      ..lineTo(size.width * 0.99, size.height * 0.64)
      ..lineTo(size.width * 0.78, size.height * 0.7)
      ..close();
    canvas.drawPath(nose, gold);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.34,
          size.height * 0.18,
          size.width * 0.22,
          size.height * 0.22,
        ),
        const Radius.circular(1.4),
      ),
      light,
    );

    void wheel(double x) {
      canvas.drawCircle(Offset(x, size.height * 0.78), 3.1, ink);
      canvas.drawCircle(Offset(x, size.height * 0.78), 1.3, gold);
    }

    wheel(size.width * 0.26);
    wheel(size.width * 0.74);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompletedResultPending extends StatelessWidget {
  final VoidCallback onRefresh;

  const _CompletedResultPending({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.champagne.withValues(alpha: 0.1),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            color: AppTheme.champagneLight,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Denemen tamamlandı. Sonucun yükleniyor…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.champagneLight,
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Yenile',
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.champagneLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardShell extends StatelessWidget {
  final Widget child;

  const _LeaderboardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8C878).withValues(alpha: 0.68),
          width: 1.15,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3D3218),
            Color(0xFF261F0F),
            Color(0xFF151107),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonGold.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DailyMiniPodium extends StatelessWidget {
  final List<DailyMiniLeaderRow> leaders;
  final int totalQuestions;

  const _DailyMiniPodium({
    required this.leaders,
    required this.totalQuestions,
  });

  DailyMiniLeaderRow? _leaderAt(int place) {
    for (final leader in leaders) {
      if (leader.rank == place) return leader;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = AuthService.instance.user?.id;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumPlace(
            place: 2,
            leader: _leaderAt(2),
            totalQuestions: totalQuestions,
            isMe: _leaderAt(2)?.userId == myUserId,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PodiumPlace(
            place: 1,
            leader: _leaderAt(1),
            totalQuestions: totalQuestions,
            isMe: _leaderAt(1)?.userId == myUserId,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _PodiumPlace(
            place: 3,
            leader: _leaderAt(3),
            totalQuestions: totalQuestions,
            isMe: _leaderAt(3)?.userId == myUserId,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardPreviewPanel extends StatelessWidget {
  final List<DailyMiniLeaderRow> leaders;
  final int participantCount;
  final int totalQuestions;

  const _LeaderboardPreviewPanel({
    required this.leaders,
    required this.participantCount,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final topThree = [...leaders]..sort((a, b) => a.rank.compareTo(b.rank));

    return _LeaderboardShell(
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 22, height: 1)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'BUGÜNÜN KÜRSÜSÜ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFFF5E6BC),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  participantCount > 0 ? '$participantCount kişi' : 'Demo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.champagneLight.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DailyMiniPodium(
            leaders: topThree,
            totalQuestions: totalQuestions,
          ),
          const SizedBox(height: 8),
          Text(
            'Denemeyi bitirince sıralamana burada yer verilir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedLeaderboardPanel extends StatelessWidget {
  final int? rank;
  final int participantCount;
  final List<DailyMiniLeaderRow> leaders;
  final int totalQuestions;
  final DailyMiniRankTrend trend;
  final VoidCallback onShare;
  final VoidCallback onDetails;

  const _CompletedLeaderboardPanel({
    required this.rank,
    required this.participantCount,
    required this.leaders,
    required this.totalQuestions,
    required this.trend,
    required this.onShare,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final topThree = [...leaders]..sort((a, b) => a.rank.compareTo(b.rank));
    final currentRank = rank;
    final hasRank = currentRank != null &&
        currentRank > 0 &&
        participantCount >= currentRank;

    return _LeaderboardShell(
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 25, height: 1)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'BUGÜNÜN KÜRSÜSÜ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Color(0xFFF5E6BC),
                  ),
                ),
              ),
              IconButton(
                onPressed: hasRank ? onShare : null,
                tooltip: 'Sıralamanı paylaş',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: AppTheme.champagneLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DailyMiniPodium(
            leaders: topThree,
            totalQuestions: totalQuestions,
          ),
          const SizedBox(height: 12),
          _RankRevealBadge(
            rank: rank,
            participantCount: participantCount,
            leaders: topThree,
            trend: trend,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onDetails,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.champagneLight,
              minimumSize: const Size(double.infinity, 42),
            ),
            icon: const Icon(Icons.leaderboard_rounded, size: 18),
            label: const Text(
              'Sıralama Detayları',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRevealBadge extends StatefulWidget {
  static const countdownSeconds = 10;

  final int? rank;
  final int participantCount;
  final List<DailyMiniLeaderRow> leaders;
  final DailyMiniRankTrend trend;

  const _RankRevealBadge({
    required this.rank,
    required this.participantCount,
    required this.leaders,
    required this.trend,
  });

  @override
  State<_RankRevealBadge> createState() => _RankRevealBadgeState();
}

class _RankRevealBadgeState extends State<_RankRevealBadge> {
  Timer? _timer;
  int _secondsLeft = _RankRevealBadge.countdownSeconds;
  bool _countdownDone = false;
  bool _celebrateRank = false;
  bool _confettiPlayed = false;

  bool get _rankRevealActive =>
      DailyMiniExamService.instance.rankRevealActive;

  int? get _resolvedRank {
    if (_showCountdown) return null;
    if (widget.rank != null && widget.rank! > 0) return widget.rank;
    if (!_countdownDone) return null;
    final userId = AuthService.instance.user?.id;
    if (userId == null) return null;
    for (final row in widget.leaders) {
      if (row.userId == userId && row.rank > 0) return row.rank;
    }
    return null;
  }

  bool get _hasRank {
    final rank = _resolvedRank;
    return rank != null &&
        rank > 0 &&
        widget.participantCount > 0 &&
        widget.participantCount >= rank;
  }

  bool get _showCountdown =>
      _rankRevealActive && !_countdownDone;

  @override
  void initState() {
    super.initState();
    if (!_showCountdown) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant _RankRevealBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_countdownDone && _hasRank) {
      _timer?.cancel();
      _timer = null;
      _triggerRankCelebration();
    } else if (_timer == null && _showCountdown) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _triggerRankCelebration() {
    if (_confettiPlayed || !_hasRank) return;
    _confettiPlayed = true;
    if (!mounted) return;
    setState(() => _celebrateRank = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    if (_secondsLeft <= 1) {
      _timer?.cancel();
      _timer = null;
      setState(() {
        _secondsLeft = 0;
        _countdownDone = true;
      });
      unawaited(
        DailyMiniExamService.instance.refresh().then((_) {
          if (mounted) _triggerRankCelebration();
        }),
      );
      DailyMiniExamService.instance.clearRankReveal();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _triggerRankCelebration();
      });
      return;
    }
    setState(() => _secondsLeft--);
  }

  @override
  Widget build(BuildContext context) {
    final rank = _resolvedRank;
    final showRank = _hasRank;

    return MiniConfettiBurst(
      trigger: _celebrateRank,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: showRank
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
            color: Color(0xFFFFE5A0).withValues(alpha: showRank ? 1 : 0.8),
            width: showRank ? 1.35 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonGold.withValues(alpha: showRank ? 0.38 : 0.22),
              blurRadius: showRank ? 16 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
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
            const SizedBox(width: 10),
            _RankRevealSlot(
              showCountdown: _showCountdown,
              secondsLeft: _secondsLeft,
              totalSeconds: _RankRevealBadge.countdownSeconds,
              rank: showRank ? rank : null,
              trend: widget.trend,
            ),
          ],
        ),
      ),
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

class _PremiumRankCountdown extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;

  const _PremiumRankCountdown({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / totalSeconds;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            AppTheme.ink.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: AppTheme.ink.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 2.8,
              backgroundColor: AppTheme.ink.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.ink),
            ),
          ),
          Text(
            '$secondsLeft',
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontFamily: 'serif',
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1,
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final int place;
  final DailyMiniLeaderRow? leader;
  final int totalQuestions;
  final bool isMe;

  const _PodiumPlace({
    required this.place,
    required this.leader,
    required this.totalQuestions,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final first = place == 1;
    final color = switch (place) {
      1 => const Color(0xFFFFD76A),
      2 => const Color(0xFFD8DDE5),
      _ => const Color(0xFFD99A62),
    };
    final height = switch (place) { 1 => 84.0, 2 => 66.0, _ => 56.0 };
    final name = isMe
        ? 'Sen'
        : leader == null
            ? '—'
            : (leader!.displayName.isNotEmpty
                ? leader!.displayName
                : leader!.emailPrefix);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: first ? 38 : 32,
          height: first ? 38 : 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.16),
            border: Border.all(color: color.withValues(alpha: 0.8)),
          ),
          child: Text(
            first ? '👑' : '$place',
            style: TextStyle(
              fontSize: first ? 19 : 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
            color: isMe ? AppTheme.neonGold : Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.34),
                  color.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.46)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$place.',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: first ? 22 : 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                if (leader != null) ...[
                  Text(
                    '${leader!.correct}/$totalQuestions',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  if (leader!.durationSeconds > 0)
                    Text(
                      formatExamDuration(leader!.durationSeconds),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  final DailyMiniAttempt attempt;
  final VoidCallback onOpen;

  const _ScoreBlock({
    required this.attempt,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = AppTheme.onPage(context);
    final muted = AppTheme.mutedOnPage(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${attempt.correct}',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 36,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: titleColor,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${attempt.total}',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Detay',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.champagne.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

