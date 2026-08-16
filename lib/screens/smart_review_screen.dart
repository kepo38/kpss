import 'package:flutter/material.dart';

import '../models/quiz_result.dart';
import '../services/ad_manager.dart';
import '../services/smart_review_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/scale_button.dart';
import '../widgets/study_empty_cta.dart';
import 'quiz_screen.dart';
import 'study_hub_screen.dart';

/// Günlük 15 soruluk akıllı tekrar (spaced repetition).
class SmartReviewScreen extends StatefulWidget {
  final KpssType kpssType;

  const SmartReviewScreen({super.key, required this.kpssType});

  @override
  State<SmartReviewScreen> createState() => _SmartReviewScreenState();
}

class _SmartReviewScreenState extends State<SmartReviewScreen> {
  final _service = SmartReviewService.instance;
  SmartReviewPack? _pack;
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pack = await _service.ensureTodayPack(widget.kpssType);
    if (!mounted) return;
    setState(() {
      _pack = pack;
      _loading = false;
    });
  }

  Future<void> _start() async {
    if (_starting) return;
    final pack = _pack;
    if (pack == null || pack.isEmpty) return;

    setState(() => _starting = true);
    final questions =
        await _service.fetchQuestionsForTodayPack(widget.kpssType);
    if (!mounted) return;
    if (questions.isEmpty) {
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bugün için soru bulunamadı.')),
      );
      return;
    }

    AdManager.instance.skipNextPageTransition();
    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute<QuizResult>(
        builder: (_) => QuizScreen(
          title: 'Akıllı Tekrar',
          questions: questions,
        ),
      ),
    );

    if (result != null && result.completed) {
      await _service.recordSessionOutcome(
        correctIds: result.correctQuestionIds,
        wrongIds: result.wrongQuestionIds,
      );
    }
    if (!mounted) return;
    setState(() => _starting = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.page(context),
        foregroundColor: AppTheme.onPage(context),
        leading: const AppBackButton(),
        title: const Text(
          'Akıllı Tekrar',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.pageTop(context),
              AppTheme.page(context),
              AppTheme.pageDeep(context),
            ],
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.champagne),
              )
            : pack == null || pack.isEmpty
                ? StudyEmptyCta(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Henüz tekrar seti yok',
                    message:
                        'Yanlış yaptığın veya düşük başarı gösterdiğin '
                        'konulardan günlük ${SmartReviewService.dailyTarget} '
                        'soruluk set oluşur. Önce bir konu testi çöz.',
                    kpssType: widget.kpssType,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: SubjectNeonPalette.lightNeonModule(
                          neon: AppTheme.neonEdge,
                          accent: true,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Günün seti',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              pack.completed
                                  ? 'Bugünkü tekrarı tamamladın. Yarın yeni set hazır.'
                                  : 'Yanlış defteri ve düşük başarı konularından '
                                      'seçilmiş ${pack.size} soru.',
                              style: TextStyle(
                                height: 1.4,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _StatPill(
                                  label: 'Soru',
                                  value: '${pack.size}',
                                ),
                                const SizedBox(width: 8),
                                _StatPill(
                                  label: 'Yanlış defteri',
                                  value: '${pack.wrongCount}',
                                ),
                                const SizedBox(width: 8),
                                _StatPill(
                                  label: 'Zayıf konu',
                                  value: '${pack.weakTopicCount}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Nasıl çalışır?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppTheme.slate.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _HowRow(
                        index: '1',
                        text: 'Önce yanlış yaptığın sorular gelir.',
                      ),
                      const _HowRow(
                        index: '2',
                        text:
                            'Başarı oranı %60 altındaki konulardan sorular eklenir.',
                      ),
                      const _HowRow(
                        index: '3',
                        text:
                            'Doğru bildiklerin ertelenir; yanlışlar yarın tekrar gelir.',
                      ),
                      const SizedBox(height: 24),
                      ScaleButton(
                        onPressed: pack.completed || _starting ? null : _start,
                        child: FilledButton.icon(
                          onPressed:
                              pack.completed || _starting ? null : _start,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.champagne,
                            foregroundColor: AppTheme.ink,
                            disabledBackgroundColor:
                                AppTheme.ink.withValues(alpha: 0.08),
                            minimumSize: const Size(double.infinity, 52),
                          ),
                          icon: _starting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  pack.completed
                                      ? Icons.check_circle_outline
                                      : Icons.play_arrow_rounded,
                                ),
                          label: Text(
                            pack.completed
                                ? 'Bugün tamamlandı'
                                : _starting
                                    ? 'Hazırlanıyor…'
                                    : 'Tekrara başla · ${pack.size} soru',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StudyHubScreen(
                                kpssType: widget.kpssType,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Müfredata git',
                          style: TextStyle(
                            color: AppTheme.champagne,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.neonEdge,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  final String index;
  final String text;

  const _HowRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.champagne.withValues(alpha: 0.18),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              index,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                height: 1.35,
                color: AppTheme.slate.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
