import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/tg_exam_constants.dart';
import '../../models/tg_exam_models.dart';
import '../../models/quiz_result.dart';
import '../../screens/quiz_screen.dart';
import '../../screens/tg_exam/tg_exam_instant_summary_screen.dart';
import '../../services/tg_exam_service.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/tg_exam_gates.dart';

/// TG deneme karşılama ekranı — bildirim deeplink veya liste tıklaması.
class ExamWelcomeScreen extends StatefulWidget {
  final int examId;

  const ExamWelcomeScreen({super.key, required this.examId});

  @override
  State<ExamWelcomeScreen> createState() => _ExamWelcomeScreenState();
}

class _ExamWelcomeScreenState extends State<ExamWelcomeScreen> {
  TgExamModel? _exam;
  bool _loading = true;
  String? _error;
  bool _starting = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final detail = await TgExamService.instance.fetchDetail(widget.examId);
    if (!mounted) return;
    if (detail == null) {
      setState(() {
        _loading = false;
        _error = 'Deneme bulunamadı veya yayında değil.';
      });
      return;
    }
    setState(() {
      _exam = detail;
      _loading = false;
    });
  }

  Future<void> _openQuiz({required bool resume}) async {
    final exam = _exam;
    if (exam == null || _starting) return;
    if (!await TgExamGates.requireGoogleAccount(context)) return;
    if (!mounted) return;
    setState(() => _starting = true);
    final payload = await TgExamService.instance.fetchQuestions(exam.id);
    if (!mounted) return;
    setState(() => _starting = false);
    if (payload == null || payload.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sorular yüklenemedi. Deneme aktif mi?'),
          backgroundColor: _TgWelcomeTheme.crimsonDeep,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final questionIds = payload.questions.map((q) => q.id).toList();
    final initialAnswers = resume
        ? TgExamService.instance.initialAnswersFor(exam, questionIds)
        : List<String?>.filled(payload.questions.length, null);
    final initialIndex = resume ? (exam.myAttempt?.currentIndex ?? 0) : 0;
    final initialElapsed = resume
        ? Duration(seconds: exam.myAttempt?.elapsedSeconds ?? 0)
        : Duration.zero;

    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: exam.title,
          questions: payload.questions,
          timeLimitMinutes: exam.effectiveCountdownMinutes(),
          initialIndex: initialIndex.clamp(0, payload.questions.length - 1),
          initialAnswers: initialAnswers,
          initialElapsed: initialElapsed,
          adFreeExperience: true,
          tgExamMode: true,
          tgExamId: exam.id,
          skipResultDialog: true,
          onProgress: ({
            required answers,
            required currentIndex,
            required elapsed,
          }) =>
              tgExamOnProgress(
            examId: exam.id,
            questions: payload.questions,
            answers: answers,
            currentIndex: currentIndex,
            elapsed: elapsed,
          ),
        ),
      ),
    );

    if (!mounted) return;
    await _load();

    if (result != null && result.completed) {
      final submitted = await submitTgExamFromQuiz(
        examId: exam.id,
        result: result,
        questions: payload.questions,
      );
      if (!mounted) return;
      if (submitted.exam != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TgExamInstantSummaryScreen(exam: submitted.exam!),
          ),
        );
        return;
      }
      if (submitted.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(submitted.error!),
            duration: const Duration(seconds: 6),
            backgroundColor: _TgWelcomeTheme.crimsonDeep,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openResults() async {
    final exam = _exam;
    if (exam == null) return;
    if (exam.canAccessDetailedAnalysis) {
      await TgExamGates.openDetailedAnalysis(context, exam);
      return;
    }
    if (exam.hasSubmittedAttempt) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TgExamInstantSummaryScreen(exam: exam),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _TgWelcomeTheme.ink,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        leading: AppBackButton.onDark(accent: Colors.white),
        title: Text(
          'Türkiye Geneli Deneme',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.92),
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _TgWelcomeBackdrop(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : _buildBody(_exam!),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(TgExamModel exam) {
    final dateFmt = DateFormat('d MMMM yyyy HH:mm', 'tr');
    final progress = _progressValue(exam);
    final statusMeta = _TgStatusMeta.from(exam.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TgHeroBadge(),
          const SizedBox(height: 18),
          Text(
            exam.title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(meta: statusMeta),
              _MetricPill(
                icon: Icons.quiz_outlined,
                label: '${exam.questionCount} soru',
              ),
              _MetricPill(
                icon: Icons.timer_outlined,
                label: '${TgExamConstants.examDurationMinutes} dk',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _TimelineCard(
            progress: progress,
            startLabel: dateFmt.format(exam.startAt),
            endLabel: dateFmt.format(exam.endAt),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            icon: Icons.play_circle_outline_rounded,
            label: 'Başlangıç',
            value: dateFmt.format(exam.startAt),
            accent: _TgWelcomeTheme.crimsonBright,
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.flag_outlined,
            label: 'Bitiş',
            value: dateFmt.format(exam.endAt),
            accent: const Color(0xFFFFB4B4),
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.menu_book_outlined,
            label: 'Kapsam',
            value:
                '${exam.questionCount} Soru · ${TgExamConstants.examDurationMinutes} Dakika',
            accent: Colors.white,
          ),
          const SizedBox(height: 28),
          _PrimaryAction(
            exam: exam,
            starting: _starting,
            onStart: () => _openQuiz(resume: false),
            onResume: () => _openQuiz(resume: true),
            onResults: _openResults,
          ),
          const SizedBox(height: 14),
          Text(
            'Türkiye genelinde eş zamanlı deneme · sonuçlar açıklandığında sıralama görünür.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }

  double _progressValue(TgExamModel exam) {
    final now = DateTime.now();
    if (now.isBefore(exam.startAt)) return 0;
    if (now.isAfter(exam.endAt)) return 1;
    final total = exam.endAt.difference(exam.startAt).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(exam.startAt).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

/// TG karşılama ekranı — kırmızı / beyaz premium palet.
abstract final class _TgWelcomeTheme {
  static const ink = Color(0xFF12080C);
  static const crimsonDeep = Color(0xFF6B0F1A);
  static const crimson = Color(0xFF9B1B2E);
  static const crimsonBright = Color(0xFFC41E3A);
  static const roseGlow = Color(0xFFFF6B7A);
}

class _TgStatusMeta {
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  const _TgStatusMeta({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  factory _TgStatusMeta.from(TgExamStatus status) {
    switch (status) {
      case TgExamStatus.notStarted:
        return _TgStatusMeta(
          label: 'Yakında',
          bg: Colors.white.withValues(alpha: 0.14),
          fg: Colors.white.withValues(alpha: 0.88),
          icon: Icons.schedule_rounded,
        );
      case TgExamStatus.active:
        return const _TgStatusMeta(
          label: 'Aktif',
          bg: Color(0x33FFFFFF),
          fg: Colors.white,
          icon: Icons.bolt_rounded,
        );
      case TgExamStatus.inProgress:
        return const _TgStatusMeta(
          label: 'Devam ediyor',
          bg: Color(0x40FFFFFF),
          fg: Colors.white,
          icon: Icons.pending_actions_rounded,
        );
      case TgExamStatus.results:
        return const _TgStatusMeta(
          label: 'Sonuçlar açık',
          bg: Color(0xFFE8F5E9),
          fg: Color(0xFF1B5E20),
          icon: Icons.emoji_events_outlined,
        );
      case TgExamStatus.submittedWaiting:
        return _TgStatusMeta(
          label: 'Sonuç bekleniyor',
          bg: Colors.white.withValues(alpha: 0.16),
          fg: Colors.white.withValues(alpha: 0.9),
          icon: Icons.hourglass_top_rounded,
        );
      case TgExamStatus.ended:
        return _TgStatusMeta(
          label: 'Süre doldu',
          bg: Colors.white.withValues(alpha: 0.12),
          fg: Colors.white.withValues(alpha: 0.75),
          icon: Icons.lock_clock_outlined,
        );
    }
  }
}

class _TgWelcomeBackdrop extends StatelessWidget {
  const _TgWelcomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1F0A10),
            Color(0xFF8B1538),
            Color(0xFF5C1024),
            Color(0xFF12080C),
          ],
          stops: [0.0, 0.38, 0.72, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _TgWelcomeTheme.roseGlow.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TgHeroBadge extends StatelessWidget {
  const _TgHeroBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFE8EA),
              Color(0xFFFFC9CF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _TgWelcomeTheme.crimsonBright,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TÜRKİYE GENELİ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: _TgWelcomeTheme.crimsonDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _TgStatusMeta meta;

  const _StatusChip({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 14, color: meta.fg),
          const SizedBox(width: 5),
          Text(
            meta.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: meta.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.82)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final double progress;
  final String startLabel;
  final String endLabel;

  const _TimelineCard({
    required this.progress,
    required this.startLabel,
    required this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Deneme süreci',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      startLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      endLabel,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.85),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: _TgWelcomeTheme.crimsonDeep, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final TgExamModel exam;
  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback onResults;

  const _PrimaryAction({
    required this.exam,
    required this.starting,
    required this.onStart,
    required this.onResume,
    required this.onResults,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMMM yyyy HH:mm', 'tr');

    switch (exam.status) {
      case TgExamStatus.notStarted:
        return _DisabledButton(
          label: 'Deneme Başlama Zamanı: ${dateFmt.format(exam.startAt)}',
        );
      case TgExamStatus.active:
        return _GradientButton(
          label: 'BAŞLA',
          loading: starting,
          onPressed: onStart,
        );
      case TgExamStatus.inProgress:
        return _GradientButton(
          label: 'Denemeye Devam Et',
          loading: starting,
          onPressed: onResume,
        );
      case TgExamStatus.results:
        return _GradientButton(
          label: 'SONUÇLARA BAK',
          loading: false,
          onPressed: onResults,
          variant: _GradientButtonVariant.outline,
        );
      case TgExamStatus.submittedWaiting:
      case TgExamStatus.ended:
        if (exam.canAccessDetailedAnalysis) {
          return _GradientButton(
            label: 'SONUÇLARA BAK',
            loading: false,
            onPressed: onResults,
            variant: _GradientButtonVariant.outline,
          );
        }
        if (exam.hasSubmittedAttempt) {
          return _GradientButton(
            label: 'PUAN ÖZETİN',
            loading: false,
            onPressed: onResults,
            variant: _GradientButtonVariant.outline,
          );
        }
        return _DisabledButton(
          label: exam.status == TgExamStatus.submittedWaiting
              ? 'Sonuçlar açıklanınca bildirileceksiniz'
              : 'Deneme süresi doldu — sonuçlar bekleniyor',
        );
    }
  }
}

enum _GradientButtonVariant { primary, outline }

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final _GradientButtonVariant variant;

  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.variant = _GradientButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _GradientButtonVariant.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isPrimary
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFF0F2),
                  Color(0xFFFFD4DA),
                ],
              )
            : null,
        color: isPrimary ? null : Colors.transparent,
        border: isPrimary
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: _TgWelcomeTheme.crimson.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 56,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isPrimary
                            ? _TgWelcomeTheme.crimsonDeep
                            : Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: isPrimary ? 16 : 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: isPrimary ? 1.4 : 0.6,
                        color: isPrimary
                            ? _TgWelcomeTheme.crimsonDeep
                            : Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DisabledButton extends StatelessWidget {
  final String label;

  const _DisabledButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _TgWelcomeTheme.crimsonDeep,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}
