import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/daily_mini_exam_constants.dart';
import '../../models/quiz_result.dart';
import '../../screens/daily_mini_exam_result_screen.dart';
import '../../screens/daily_mini_rewards_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/quiz_screen.dart';
import '../../services/ad_manager.dart';
import '../../services/auth_service.dart';
import '../../services/daily_mini_exam_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/daily_mini_exam_logic.dart';
import '../countdown_widget.dart';
import '../scale_button.dart';
import 'daily_mini_exam_cta.dart';
import 'daily_mini_exam_header.dart';
import 'daily_mini_exam_leaderboard.dart';
import 'daily_mini_exam_podium_share.dart';
import 'daily_mini_exam_subjects.dart';

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
  final GlobalKey _podiumShareKey = GlobalKey();
  bool _sharingPodium = false;

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
    if (_sharingPodium) return;
    final service = DailyMiniExamService.instance;
    final attempt = service.attempt;
    final rank = service.rankForCurrentUser();
    final participantCount = service.visibleParticipantCount;
    if (attempt == null || rank == null || participantCount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sıralama henüz hazır değil. Birkaç saniye sonra tekrar dene.'),
        ),
      );
      unawaited(service.refresh());
      return;
    }
    final text = buildDailyMiniShareText(
      rank: rank,
      participantCount: participantCount,
      correct: attempt.correct,
      total: attempt.total,
    );
    setState(() => _sharingPodium = true);
    await WidgetsBinding.instance.endOfFrame;
    final ok = await DailyMiniPodiumShare.share(
      boundaryKey: _podiumShareKey,
      shareText: text,
    );
    if (mounted) setState(() => _sharingPodium = false);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paylaşım açılamadı. Metin panosu kullanıldı.')),
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
    if (!mounted) return;
    await DailyMiniExamService.instance.onAuthSessionChanged();
    if (mounted) setState(() {});
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

  Future<void> _openRewards() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DailyMiniRewardsScreen(),
      ),
    );
  }

  Future<void> _startOrResume() async {
    final service = DailyMiniExamService.instance;
    if (service.guestMustSignIn) {
      await _openProfileForLogin();
      return;
    }
    if (service.formallyFinished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bugünkü mini denemeyi tamamladın.'),
        ),
      );
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
      await service.markFormallyFinished();
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
            : (service.hasInProgress && service.canResumeQuiz
                ? DailyMiniExamConstants.ctaResume
                : (_window.isOpen
                    ? DailyMiniExamConstants.ctaStart
                    : '${DailyMiniExamConstants.opensClock}’de açılır'));
        final rank = service.rankForCurrentUser();
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
                      child: DailyMiniExamFreeRibbon(dark: dark),
                    ),
                    Positioned(
                      top: 10,
                      right: 12,
                      child: DailyMiniExamClosingTimer(
                        window: _window,
                        dark: dark,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 30, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DailyMiniExamHeader(),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _openRewards,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.champagneLight,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                              ),
                              icon: const Icon(Icons.emoji_events_outlined, size: 16),
                              label: const Text(
                                'ÖDÜL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                          if (!submittedRanking) ...[
                            const SizedBox(height: 10),
                            const DailyMiniExamSubjectMix(),
                            if (service.leaderboard.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              DailyMiniExamLeaderboardPreview(
                                leaders: service.leaderboard,
                                participantCount: service.podiumParticipantCount,
                                totalQuestions:
                                    DailyMiniExamConstants.questionCount,
                                headline: service.showingYesterdayPodium
                                    ? 'DÜNÜN KÜRSÜSÜ'
                                    : 'BUGÜNÜN KÜRSÜSÜ',
                                footer: service.showingYesterdayPodium
                                    ? 'Yeni deneme ${DailyMiniExamConstants.opensClock}\'de açılır.'
                                    : 'Denemeyi bitirince sıralamana burada yer verilir.',
                              ),
                            ],
                            const SizedBox(height: 14),
                            ScaleButton(
                              onPressed: guestMustSignIn
                                  ? _openProfileForLogin
                                  : _startOrResume,
                              child: DailyMiniExamCta(
                                label: ctaLabel,
                                enabled: guestMustSignIn || _window.isOpen,
                                twoLineStart: ctaLabel ==
                                    DailyMiniExamConstants.ctaStart,
                              ),
                            ),
                          ] else if (attempt != null) ...[
                            const SizedBox(height: 10),
                            const DailyMiniExamSubjectMix(),
                            const SizedBox(height: 12),
                            DailyMiniExamCompletedLeaderboard(
                              shareBoundaryKey: _podiumShareKey,
                              rank: rank,
                              participantCount: service.visibleParticipantCount,
                              leaders: service.leaderboard,
                              totalQuestions:
                                  DailyMiniExamConstants.questionCount,
                              trend: service.rankTrend,
                              onShare: _shareRank,
                              onDetails: _openResult,
                              shareEnabled: service.canShareRank,
                            ),
                            if (service.canResumeQuiz && _window.isOpen) ...[
                              const SizedBox(height: 12),
                              ScaleButton(
                                onPressed: _startOrResume,
                                child: const DailyMiniExamCta(
                                  label: DailyMiniExamConstants.ctaResume,
                                  enabled: true,
                                ),
                              ),
                            ],
                          ] else ...[
                            const SizedBox(height: 14),
                            DailyMiniExamCompletedPending(
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
