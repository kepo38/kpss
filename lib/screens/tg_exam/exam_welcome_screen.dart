import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/tg_exam_constants.dart';
import '../../models/tg_exam_models.dart';
import '../../models/quiz_result.dart';
import '../../screens/quiz_screen.dart';
import '../../screens/tg_exam/tg_exam_instant_summary_screen.dart';
import '../../services/tg_exam_service.dart';
import '../../theme/app_theme.dart';
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
        const SnackBar(content: Text('Sorular yüklenemedi. Deneme aktif mi?')),
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
          timeLimitMinutes: TgExamConstants.examDurationMinutes,
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
      if (submitted != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TgExamInstantSummaryScreen(exam: submitted),
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
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.inkSoft,
        foregroundColor: Colors.white,
        leading: AppBackButton.onDark(accent: AppTheme.champagne),
        title: const Text(
          'Türkiye Geneli Deneme',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.champagne),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _buildBody(_exam!),
    );
  }

  Widget _buildBody(TgExamModel exam) {
    final dateFmt = DateFormat('d MMMM yyyy HH:mm', 'tr');
    final status = exam.status;
    final progress = _progressValue(exam);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            exam.title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: AppTheme.champagne,
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            icon: Icons.calendar_today_outlined,
            label: 'Başlangıç',
            value: dateFmt.format(exam.startAt),
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.event_busy_outlined,
            label: 'Bitiş',
            value: dateFmt.format(exam.endAt),
          ),
          const SizedBox(height: 10),
          _InfoCard(
            icon: Icons.quiz_outlined,
            label: 'Kapsam',
            value:
                '${exam.questionCount} Soru · ${TgExamConstants.examDurationMinutes} Dakika',
          ),
          const SizedBox(height: 28),
          _PrimaryAction(
            exam: exam,
            starting: _starting,
            onStart: () => _openQuiz(resume: false),
            onResume: () => _openQuiz(resume: true),
            onResults: _openResults,
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.inkSoft,
            AppTheme.inkSoft.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.champagne.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.champagne, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
        );
      case TgExamStatus.submittedWaiting:
      case TgExamStatus.ended:
        if (exam.canAccessDetailedAnalysis) {
          return _GradientButton(
            label: 'SONUÇLARA BAK',
            loading: false,
            onPressed: onResults,
          );
        }
        if (exam.hasSubmittedAttempt) {
          return _GradientButton(
            label: 'PUAN ÖZETİN',
            loading: false,
            onPressed: onResults,
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

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE2C998),
            AppTheme.champagne,
            Color(0xFFB8944A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onPressed,
          child: SizedBox(
            height: 54,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.ink,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppTheme.ink,
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
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.45),
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.champagne,
                foregroundColor: AppTheme.ink,
              ),
              child: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}
