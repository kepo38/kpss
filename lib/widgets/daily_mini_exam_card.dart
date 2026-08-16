import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/daily_mini_exam_constants.dart';
import '../models/daily_mini_exam_models.dart';
import '../models/quiz_result.dart';
import '../screens/daily_mini_exam_result_screen.dart';
import '../screens/quiz_screen.dart';
import '../services/ad_manager.dart';
import '../services/auth_service.dart';
import '../services/daily_mini_exam_service.dart';
import '../theme/app_theme.dart';
import '../utils/daily_mini_exam_logic.dart';
import '../widgets/countdown_widget.dart';
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
      if (DailyMiniExamService.instance.completed) {
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
        DailyMiniExamService.instance.completed) {
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
          initialIndex: service.hasInProgress ? service.currentIndex : 0,
          initialAnswers: service.hasInProgress ? service.answers : null,
          initialElapsed: Duration(seconds: service.elapsedSeconds),
          skipResultDialog: true,
          adFreeExperience: true,
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
    if (result == null || !result.completed) return;

    await service.recordCompletion(
      result: result,
      answers: result.selectedAnswers,
    );
    if (!mounted) return;
    await _openResult();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DailyMiniExamService.instance,
      builder: (context, _) {
        final service = DailyMiniExamService.instance;
        final attempt = service.attempt;
        final completed = service.completed;
        final ctaLabel = service.hasInProgress
            ? DailyMiniExamConstants.ctaResume
            : (_window.isOpen
                ? DailyMiniExamConstants.ctaStart
                : '${DailyMiniExamConstants.opensClock}’de açılır');
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
                          if (!completed) ...[
                            const SizedBox(height: 10),
                            const _SubjectMix(),
                            const SizedBox(height: 14),
                            ScaleButton(
                              onPressed: _startOrResume,
                              child: _StartExamCta(
                                label: ctaLabel,
                                enabled: _window.isOpen,
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

class _StartExamCta extends StatelessWidget {
  final String label;
  final bool enabled;

  const _StartExamCta({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final disabledFill = dark
        ? Colors.white.withValues(alpha: 0.08)
        : AppTheme.ink.withValues(alpha: 0.06);
    final disabledText = dark
        ? Colors.white.withValues(alpha: 0.55)
        : AppTheme.slate.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: enabled
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
        color: enabled ? null : disabledFill,
        border: Border.all(
          color: enabled
              ? AppTheme.champagne.withValues(alpha: 0.55)
              : AppTheme.hairline(context),
        ),
        boxShadow: enabled
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
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.15,
                color: enabled ? AppTheme.ink : disabledText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '🏆',
            style: TextStyle(
              fontSize: 22,
              height: 1,
              color: enabled ? null : disabledText,
            ),
          ),
        ],
      ),
    );
  }
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
    final topThree = [...leaders]
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final currentRank = rank;
    final hasRank = currentRank != null &&
        currentRank > 0 &&
        participantCount >= currentRank;
    final myUserId = AuthService.instance.user?.id;

    DailyMiniLeaderRow? leaderAt(int place) {
      for (final leader in topThree) {
        if (leader.rank == place) return leader;
      }
      return null;
    }

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PodiumPlace(
                  place: 2,
                  leader: leaderAt(2),
                  totalQuestions: totalQuestions,
                  isMe: leaderAt(2)?.userId == myUserId,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PodiumPlace(
                  place: 1,
                  leader: leaderAt(1),
                  totalQuestions: totalQuestions,
                  isMe: leaderAt(1)?.userId == myUserId,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PodiumPlace(
                  place: 3,
                  leader: leaderAt(3),
                  totalQuestions: totalQuestions,
                  isMe: leaderAt(3)?.userId == myUserId,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFEDB0),
                  Color(0xFFE8C878),
                  AppTheme.champagne,
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFE5A0).withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonGold.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 20,
                  color: AppTheme.ink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasRank
                        ? formatRankBadgeLine(
                            participantCount: participantCount,
                            rank: currentRank,
                          )
                        : 'Bugünkü sıralaman hesaplanıyor…',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                if (hasRank && trend == DailyMiniRankTrend.worsened)
                  Semantics(
                    label: 'Sıralaman düştü',
                    child: const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 24,
                      color: Color(0xFF8E0000),
                    ),
                  )
                else if (hasRank && trend == DailyMiniRankTrend.improved)
                  Semantics(
                    label: 'Sıralaman yükseldi',
                    child: const Icon(
                      Icons.arrow_drop_up_rounded,
                      size: 24,
                      color: Color(0xFF145A20),
                    ),
                  ),
              ],
            ),
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
            : leader!.emailPrefix;

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
                if (leader != null)
                  Text(
                    '${leader!.correct}/$totalQuestions',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
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

