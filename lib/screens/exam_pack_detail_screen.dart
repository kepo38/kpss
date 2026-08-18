import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exam_pack_model.dart';
import '../models/quiz_result.dart';
import '../services/exam_pack_analytics_bridge.dart';
import '../services/exam_pack_service.dart';
import '../services/play_billing_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/account_link_card.dart';
import '../widgets/app_back_button.dart';
import 'quiz_screen.dart';

/// Deneme paketi detayı — alt deneme listesi ve quiz başlatma.
class ExamPackDetailScreen extends StatefulWidget {
  final ExamPackModel pack;

  const ExamPackDetailScreen({super.key, required this.pack});

  @override
  State<ExamPackDetailScreen> createState() => _ExamPackDetailScreenState();
}

class _ExamPackDetailScreenState extends State<ExamPackDetailScreen> {
  final _svc = ExamPackService.instance;
  final _billing = PlayBillingService.instance;

  ExamPackModel? _detail;
  bool _loading = true;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _billing.packOwnershipRevision.addListener(_onBillingChanged);
    unawaited(_loadDetail());
  }

  @override
  void dispose() {
    _billing.packOwnershipRevision.removeListener(_onBillingChanged);
    super.dispose();
  }

  void _onBillingChanged() {
    if (mounted) setState(() {});
  }

  ExamPackModel get _pack => _detail ?? widget.pack;

  bool get _owned => _svc.isPackOwned(_pack);

  Color get _neon {
    final subjectId = _pack.subjectId;
    if (subjectId != null && subjectId.isNotEmpty) {
      return SubjectNeonPalette.forSubject(subjectId);
    }
    return AppTheme.neonGold;
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    final detail = await _svc.fetchDetail(widget.pack.id);
    if (mounted) {
      setState(() {
        _detail = detail ?? widget.pack;
        _loading = false;
      });
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    final ok = await AccountLinkCard.prompt(
      context,
      title: 'Google ile giriş yap',
      subtitle:
          'Deneme paketlerini satın almak ve çözmek için Google hesabınızı bağlayın. '
          'Böylece daha önce çözdüğünüz sorular oturumda en fazla %20 olur.',
    );
    return ok;
  }

  Future<void> _buyPack() async {
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final sku = _pack.playProductId.trim();
    if (sku.isEmpty) {
      _showMessage('Bu paket için Play Store SKU tanımlı değil.');
      return;
    }
    setState(() => _buying = true);
    final ok = await _billing.purchasePack(sku);
    if (!mounted) return;
    setState(() => _buying = false);
    if (!ok && _billing.lastError != null) {
      _showMessage(_billing.lastError!);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _startExam(ExamPackExamSummary exam) async {
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    if (_pack.playProductId.isNotEmpty && !_owned) {
      await _buyPack();
      if (!_svc.isPackOwned(_pack)) return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final fetch = await _svc.fetchExamQuestions(
      packId: _pack.id,
      examIndex: exam.index,
    );
    if (!mounted) return;
    Navigator.of(context).pop();

    if (fetch.questions.isEmpty) {
      _showMessage(fetch.errorMessage ?? 'Sorular yüklenemedi.');
      return;
    }

    final meta = ExamPackQuizMeta(
      packId: _pack.id,
      packTitle: _pack.title,
      examIndex: exam.index,
      examTitle: exam.title,
      branchSubjectName: _pack.subjectName,
    );

    final result = await Navigator.of(context).push<QuizResult>(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: exam.title,
          questions: fetch.questions,
          timeLimitMinutes: _pack.timeLimitMinutes,
          adFreeExperience: true,
        ),
      ),
    );

    if (result == null || !result.completed) return;

    ExamPackAnalyticsBridge.record(
      meta: meta,
      result: result,
      questions: fetch.questions,
      answers: result.selectedAnswers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final exams = _pack.exams;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(
          _pack.title,
          style: const TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: SubjectNeonPalette.lightNeonModule(
                    neon: _neon,
                    accent: true,
                    radius: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pack.description.isNotEmpty
                            ? _pack.description
                            : '${_pack.examCount} denemelik paket',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_pack.examCount} deneme · ${_pack.timeLimitMinutes} dk'
                        '${_pack.questionsPerExam > 0 ? ' · ${_pack.questionsPerExam} soru/deneme' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _neon.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Google hesabı gerekir. Sorular 1000+ çözümlü orta zorluktadır; '
                        'daha önce cevapladığınız sorular en fazla %20 olabilir.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_owned && _pack.playProductId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _buying ? null : _buyPack,
                    icon: _buying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.shopping_bag_outlined),
                    label: Text(_svc.displayPrice(_pack)),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: _neon,
                      foregroundColor: AppTheme.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Denemeler',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 10),
                if (exams.isEmpty)
                  Text(
                    'Henüz deneme üretilmemiş.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  )
                else
                  ...exams.map(
                    (exam) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ExamTile(
                        neon: _neon,
                        exam: exam,
                        locked:
                            _pack.playProductId.isNotEmpty && !_owned,
                        onTap: () => _startExam(exam),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  final Color neon;
  final ExamPackExamSummary exam;
  final bool locked;
  final VoidCallback onTap;

  const _ExamTile({
    required this.neon,
    required this.exam,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: SubjectNeonPalette.lightNeonModule(neon: neon, radius: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: neon.withValues(alpha: 0.16),
                  child: Text(
                    '${exam.index}',
                    style: TextStyle(
                      color: neon,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${exam.questionCount} soru',
                        style: TextStyle(
                          fontSize: 12,
                          color: neon.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked ? Icons.lock_outline : Icons.play_arrow_rounded,
                  color: neon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
