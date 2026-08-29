import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/tg_exam_models.dart';
import '../../models/question_model.dart';
import '../../screens/quiz_screen.dart';
import '../../services/play_billing_service.dart';
import '../../services/premium_service.dart';
import '../../services/question_fetch_service.dart';
import '../../services/tg_exam_analysis_helper.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/pro_feature_lock.dart';

/// TG deneme sonuç detayı — derece, net dağılımı, çözüm inceleme.
class TgExamResultScreen extends StatefulWidget {
  final TgExamModel exam;

  const TgExamResultScreen({super.key, required this.exam});

  /// Çözüm inceleme quiz ekranını açar (kart / özet / detay ortak).
  static Future<void> openSolutionsReview(
    BuildContext context,
    TgExamModel exam,
  ) async {
    if (!exam.canAccessSolutions) return;

    final attempt = exam.myAttempt;
    final ids = exam.questionIds.isNotEmpty
        ? exam.questionIds
        : attempt?.answers.keys.toList() ?? const [];

    final questions = QuestionModel.forTgExamDisplayList(
      await QuestionFetchService.instance.fetchByIds(ids),
    );
    if (!context.mounted || questions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çözümler için sorular yüklenemedi.')),
        );
      }
      return;
    }

    final initialAnswers =
        questions.map((q) => attempt?.answers[q.id]).toList(growable: false);

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: exam.title,
          questions: questions,
          initialAnswers: initialAnswers,
          hideQuestionCounter: true,
          adFreeExperience: true,
          tgExamMode: true,
          tgExamSolutionReview: true,
          skipResultDialog: true,
        ),
      ),
    );
  }

  @override
  State<TgExamResultScreen> createState() => _TgExamResultScreenState();
}

class _TgExamResultScreenState extends State<TgExamResultScreen> {
  late TgExamModel _exam;
  bool _loadingSolutions = false;

  @override
  void initState() {
    super.initState();
    _exam = widget.exam;
  }

  Future<void> _openSolutions() async {
    if (_loadingSolutions || !_exam.canAccessSolutions) return;
    setState(() => _loadingSolutions = true);
    await TgExamResultScreen.openSolutionsReview(context, _exam);
    if (mounted) setState(() => _loadingSolutions = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PlayBillingService.instance.premiumNotifier,
      builder: (context, _, __) {
        final isPremium = PremiumService.instance.isPremium;
        return _buildBody(context, isPremium);
      },
    );
  }

  Widget _buildBody(BuildContext context, bool isPremium) {
    final attempt = _exam.myAttempt;
    final rank = attempt?.ranking;
    final participants = _exam.participantCount;
    final showRank = _exam.canAccessDetailedAnalysis &&
        isPremium &&
        rank != null &&
        participants > 0;
    final success = _exam.displaySuccessPercent;
    final percentile = showRank
        ? TgExamAnalysisHelper.percentileLabel(
            ranking: rank,
            participantCount: participants,
          )
        : null;
    final fireSubjects = TgExamAnalysisHelper.fireSubjectLabels(
      attempt?.subjectNets ?? {},
    );

    final proAnalysis = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _RingStat(
              percent: success,
              label: 'Başarı',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rank != null && participants > 0)
                    Text(
                      '$participants kişi içinde $rank. oldun',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.champagne,
                      ),
                    ),
                  if (percentile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      percentile,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ),
                  ],
                  if (_exam.averageNet != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Türkiye ort.: ${_exam.averageNet!.toStringAsFixed(2)} net',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ),
                  ],
                  if (participants > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Toplam katılımcı: $participants',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (fireSubjects.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Fire verdiğin dersler',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppTheme.onPage(context),
            ),
          ),
          const SizedBox(height: 8),
          ...fireSubjects.map(
            (subject) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_down_rounded,
                    size: 18,
                    color: const Color(0xFFF87171).withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    subject,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Ders Bazlı Net',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppTheme.onPage(context),
          ),
        ),
        const SizedBox(height: 12),
        ..._subjectRows(attempt?.subjectNets ?? {}),
      ],
    );

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.barSurface(context),
        foregroundColor: AppTheme.onPage(context),
        leading: AppBackButton.onDark(accent: AppTheme.champagne),
        title: Text(
          'Sonuç Detayı',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _exam.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.onPage(context),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Net: ${(attempt?.net ?? 0).toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.champagne,
            ),
          ),
          const SizedBox(height: 20),
          if (_exam.canAccessDetailedAnalysis)
            ProFeatureLock(
              locked: !isPremium,
              upsellTitle: 'TÜRKİYE GENELİ ANALİZ',
              upsellSubtitle: TgExamAnalysisHelper.proUpsellSubtitle,
              child: proAnalysis,
            )
          else if (_exam.hasSubmittedAttempt)
            Text(
              'Detaylı analiz ve sıralama sonuçlar açıklandığında görünür.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.mutedOnPage(context),
              ),
            ),
          const SizedBox(height: 28),
          if (_exam.canAccessDetailedAnalysis) ...[
            if (_exam.canAccessSolutions)
              FilledButton.icon(
                onPressed: _loadingSolutions ? null : _openSolutions,
                icon: _loadingSolutions
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.menu_book_outlined),
                label: const Text('Çözümleri İncele'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.champagne,
                  foregroundColor: AppTheme.ink,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _subjectRows(Map<String, double> nets) {
    if (nets.isEmpty) {
      return [
        Text(
          'Ders dağılımı henüz yok.',
          style: GoogleFonts.inter(color: AppTheme.mutedOnPage(context)),
        ),
      ];
    }
    final entries = nets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tgExamSubjectLabel(e.key),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  e.value.toStringAsFixed(2),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.champagne,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

class _RingStat extends StatelessWidget {
  final double percent;
  final String label;

  const _RingStat({required this.percent, required this.label});

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 8,
              backgroundColor: AppTheme.hairline(context),
              color: AppTheme.champagne,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '%${percent.round()}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.mutedOnPage(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
