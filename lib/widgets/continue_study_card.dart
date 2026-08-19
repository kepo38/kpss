import 'package:flutter/material.dart';

import '../models/content_models.dart';
import '../models/quiz_result.dart';
import '../screens/quiz_screen.dart';
import '../screens/smart_review_screen.dart';
import '../screens/topic_detail_screen.dart';
import '../screens/wrong_questions_screen.dart';
import '../services/ad_manager.dart';
import '../services/content_bank_service.dart';
import '../services/gamification_service.dart';
import '../services/last_study_session_service.dart';
import '../services/question_fetch_service.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Son çalışma oturumuna dönen CTA — oturum yoksa gizlenir.
class ContinueStudyCard extends StatelessWidget {
  const ContinueStudyCard({super.key});

  static const _neonPurple = Color(0xFF9333EA);
  static const _neonBlue = Color(0xFF3B82F6);

  Future<void> _open(BuildContext context, LastStudySession session) async {
    if (session.kind == LastStudyKind.quiz) {
      await _openQuiz(context, session);
      return;
    }

    final Widget screen = switch (session.kind) {
      LastStudyKind.topic => TopicDetailScreen(
          kpssType: session.kpssType,
          subjectId: session.subjectId!,
          topicId: session.topicId!,
        ),
      LastStudyKind.smartReview => SmartReviewScreen(
          kpssType: session.kpssType,
        ),
      LastStudyKind.wrongNotebook => const WrongQuestionsScreen(),
      LastStudyKind.quiz => TopicDetailScreen(
          kpssType: session.kpssType,
          subjectId: session.subjectId!,
          topicId: session.topicId!,
        ),
    };

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _openQuiz(
    BuildContext context,
    LastStudySession session,
  ) async {
    final bank = ContentBankService.instance;
    final testId = session.testId;
    if (testId == null ||
        session.subjectId == null ||
        session.topicId == null) {
      return;
    }

    await bank.initialize();
    var questions = bank.questionsByIds(session.questionIds);
    if (questions.length != session.questionIds.length) {
      questions = await QuestionFetchService.instance.fetchByIds(
        session.questionIds,
      );
    }
    if (questions.length != session.questionIds.length) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıtlı test soruları bulunamadı.'),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;

    AdManager.instance.skipNextPageTransition();
    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(
          title: session.testDisplayName,
          questions: questions,
          timeLimitMinutes: session.timeLimitMinutes,
          initialIndex: session.currentIndex,
          initialAnswers: session.answers,
          initialElapsed: Duration(seconds: session.elapsedSeconds),
          resumeMeta: QuizResumeMeta(
            testId: testId,
            kpssType: session.kpssType,
            subjectId: session.subjectId!,
            topicId: session.topicId!,
          ),
        ),
      ),
    );

    if (result == null || !result.completed) return;

    await bank.recordAttempt(
      TestAttemptModel(
        id: 'att_${DateTime.now().millisecondsSinceEpoch}',
        testId: testId,
        topicId: session.topicId!,
        kpssType: session.kpssType,
        correct: result.correct,
        wrong: result.wrong,
        blank: result.blank,
        total: result.total,
        duration: result.duration,
        completedAt: DateTime.now(),
      ),
      questionIds: [
        ...result.correctQuestionIds,
        ...result.wrongQuestionIds,
      ],
      wrongQuestionIds: result.wrongQuestionIds,
    );
    await GamificationService.instance.recordTestCompleted(
      correct: result.correct,
      wrong: result.wrong,
      duration: result.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LastStudySessionService.instance,
      builder: (context, _) {
        final service = LastStudySessionService.instance;
        final session = service.session;
        if (session == null) return const SizedBox.shrink();

        final isQuiz = session.kind == LastStudyKind.quiz;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ScaleButton(
            onPressed: () => _open(context, session),
            child: isQuiz
                ? _QuizResumeCard(
                    session: session,
                    when: service.relativeLabel(session.updatedAt),
                    neonPurple: _neonPurple,
                    neonBlue: _neonBlue,
                  )
                : _GenericResumeCard(
                    session: session,
                    when: service.relativeLabel(session.updatedAt),
                  ),
          ),
        );
      },
    );
  }
}

class _QuizResumeCard extends StatelessWidget {
  final LastStudySession session;
  final String when;
  final Color neonPurple;
  final Color neonBlue;

  const _QuizResumeCard({
    required this.session,
    required this.when,
    required this.neonPurple,
    required this.neonBlue,
  });

  @override
  Widget build(BuildContext context) {
    final subject = session.subjectName ?? '—';
    final topic = session.topicName ?? '—';
    final test = session.testDisplayName;
    final progress = session.quizProgressFraction;
    final muted = AppTheme.mutedOnPage(context);
    final on = AppTheme.onPage(context);
    final neon = Color.lerp(neonPurple, neonBlue, 0.45)!;

    return _PulsingNeonFrame(
      neon: neon,
      neonSecondary: neonBlue,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.surfaceCard(context).withValues(alpha: 0.96),
              neonPurple.withValues(alpha: 0.14),
              neonBlue.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        neonPurple.withValues(alpha: 0.22),
                        neonBlue.withValues(alpha: 0.18),
                      ],
                    ),
                    border: Border.all(color: neon.withValues(alpha: 0.55)),
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: on,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NeonEmbossedTitle(
                    text: 'KALDIĞIN SORUDAN DEVAM ET',
                    neon: neon,
                    neonPurple: neonPurple,
                    neonBlue: neonBlue,
                    foreground: on,
                  ),
                ),
                if (when.isNotEmpty)
                  Text(
                    when,
                    style: TextStyle(
                      fontSize: 9,
                      color: muted.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _MetaChip(label: 'Ders', value: subject, accent: neon),
            const SizedBox(height: 5),
            _MetaChip(label: 'Konu', value: topic, accent: neon),
            if (session.hasQuizProgress) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: neonPurple.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(neon),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.quiz_outlined, size: 14, color: neon),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          test,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: on,
                          ),
                        ),
                      ),
                      if (session.hasQuizProgress) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: neonPurple.withValues(alpha: 0.12),
                            border: Border.all(
                              color: neon.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            session.progressLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: on,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (session.hasQuizProgress)
                  _DevamPill(accent: neon, neonBlue: neonBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NeonEmbossedTitle extends StatelessWidget {
  final String text;
  final Color neon;
  final Color neonPurple;
  final Color neonBlue;
  final Color foreground;

  const _NeonEmbossedTitle({
    required this.text,
    required this.neon,
    required this.neonPurple,
    required this.neonBlue,
    required this.foreground,
  });

  static const _styleBase = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.9,
    height: 1.1,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(0, 2.5),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _styleBase.copyWith(
              color: neonPurple.withValues(alpha: 0.45),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 1.2),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: _styleBase.copyWith(
              color: neonBlue.withValues(alpha: 0.35),
            ),
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: _styleBase.copyWith(
            color: foreground,
            shadows: [
              Shadow(
                color: neon.withValues(alpha: 0.55),
                offset: const Offset(0, 0),
                blurRadius: 6,
              ),
              Shadow(
                color: Colors.white.withValues(alpha: 0.35),
                offset: const Offset(0, -0.8),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevamPill extends StatelessWidget {
  final Color accent;
  final Color neonBlue;

  const _DevamPill({required this.accent, required this.neonBlue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.28),
            neonBlue.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Devam',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          SizedBox(width: 3),
          Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.ink),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _MetaChip({
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = accent ?? AppTheme.champagne;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: chipColor.withValues(alpha: 0.14),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: chipColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onPage(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenericResumeCard extends StatelessWidget {
  final LastStudySession session;
  final String when;

  const _GenericResumeCard({
    required this.session,
    required this.when,
  });

  IconData _iconFor(LastStudySession session) {
    return switch (session.kind) {
      LastStudyKind.topic => Icons.menu_book_outlined,
      LastStudyKind.smartReview => Icons.auto_awesome_outlined,
      LastStudyKind.wrongNotebook => Icons.note_alt_outlined,
      LastStudyKind.quiz => Icons.quiz_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOnPage(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.surfaceCard(context),
        border: Border.all(color: AppTheme.hairline(context)),
      ),
      child: Row(
        children: [
          Icon(_iconFor(session), size: 20, color: AppTheme.champagne),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KALDIĞIN YERDEN DEVAM ET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onPage(context),
                  ),
                ),
                if (session.subtitle != null &&
                    session.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    session.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ],
            ),
          ),
          if (when.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(when, style: TextStyle(fontSize: 10, color: muted)),
            ),
          Icon(Icons.chevron_right_rounded, color: muted, size: 20),
        ],
      ),
    );
  }
}

/// Çerçeve neonunun yumuşak nefes alan / yanıp sönen ışıltısı.
class _PulsingNeonFrame extends StatefulWidget {
  final Color neon;
  final Color? neonSecondary;
  final Widget child;

  const _PulsingNeonFrame({
    required this.neon,
    this.neonSecondary,
    required this.child,
  });

  @override
  State<_PulsingNeonFrame> createState() => _PulsingNeonFrameState();
}

class _PulsingNeonFrameState extends State<_PulsingNeonFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        final borderAlpha = 0.35 + (0.5 * t);
        final glowAlpha = 0.1 + (0.28 * t);
        final blur = 5.0 + (8.0 * t);
        final spread = 0.0 + (0.5 * t);
        final borderColor = Color.lerp(widget.neon, widget.neonSecondary, t)!;
        final secondary = widget.neonSecondary ?? widget.neon;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: borderColor.withValues(alpha: borderAlpha),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.neon.withValues(alpha: glowAlpha),
                blurRadius: blur,
                spreadRadius: spread,
              ),
              BoxShadow(
                color: secondary.withValues(alpha: glowAlpha * 0.85),
                blurRadius: blur * 1.35,
                spreadRadius: spread * 0.4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
