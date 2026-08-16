import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/subject_performance.dart';
import '../services/content_bank_service.dart';
import '../services/performance_summary_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/app_back_button.dart';
import '../widgets/countdown_widget.dart';
import 'study_hub_screen.dart';

/// Ders bazlı konu/test geçmişi (Gelişim sekmesi detayı).
class SubjectAnalyticsDetailScreen extends StatelessWidget {
  final KpssType kpssType;
  final String subjectId;
  final String subjectName;

  const SubjectAnalyticsDetailScreen({
    super.key,
    required this.kpssType,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context) {
    final accent = SubjectNeonPalette.forSubject(subjectId);

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.page(context),
        foregroundColor: AppTheme.onPage(context),
        leading: const AppBackButton(),
        title: Row(
          children: [
            Icon(subjectIcon(subjectId), color: accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subjectName,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: ContentBankService.instance,
        builder: (context, _) {
          final history = PerformanceSummaryService.instance
              .subjectAttemptHistory(kpssType, subjectId);

          if (!history.hasActivity) {
            return _EmptyState(accent: accent);
          }

          var totalCorrect = 0;
          var totalWrong = 0;
          for (final group in history.topics) {
            for (final a in group.attempts) {
              totalCorrect += a.correct;
              totalWrong += a.wrong;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                  ),
                  color: Colors.white.withValues(alpha: 0.88),
                ),
                child: Text(
                  '${history.totalAttempts} test · '
                  '${history.topics.length} konu · '
                  '$totalCorrect doğru · $totalWrong yanlış',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              for (final group in history.topics) ...[
                _TopicSection(group: group, accent: accent),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color accent;

  const _EmptyState({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: accent.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz bu derste test çözülmedi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.onPage(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Konu testlerini çözdükçe burada konu bazlı geçmişin görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.mutedOnPage(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicSection extends StatelessWidget {
  final TopicAttemptGroup group;
  final Color accent;

  const _TopicSection({
    required this.group,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.topicName,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
            ),
            Text(
              '${group.attemptCount} test',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final attempt in group.attempts)
          _AttemptTile(attempt: attempt, accent: accent),
      ],
    );
  }
}

class _AttemptTile extends StatelessWidget {
  final AttemptDetail attempt;
  final Color accent;

  const _AttemptTile({
    required this.attempt,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d.MM.yyyy · HH:mm').format(
      attempt.completedAt.toLocal(),
    );
    final rate = (attempt.successRate * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.07)),
        color: Colors.white.withValues(alpha: 0.82),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attempt.testTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.slate.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ResultChip(
                label: '${attempt.correct} doğru',
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              _ResultChip(
                label: '${attempt.wrong} yanlış',
                color: const Color(0xFFDC2626),
              ),
              if (attempt.blank > 0) ...[
                const SizedBox(width: 8),
                _ResultChip(
                  label: '${attempt.blank} boş',
                  color: AppTheme.slate,
                ),
              ],
              const Spacer(),
              Text(
                '%$rate',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ResultChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color.withValues(alpha: 0.9),
      ),
    );
  }
}
