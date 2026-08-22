import '../models/practice_exam_model.dart';
import '../models/tg_exam_models.dart';
import '../widgets/net_development_chart.dart';
import 'practice_exam_service.dart';
import 'tg_exam_service.dart';

/// TG + yayınevi denemelerini tek gelişim grafiğinde birleştirir.
class ExamTrendService {
  ExamTrendService._();
  static final ExamTrendService instance = ExamTrendService._();

  static const _gySlugs = {'turkce', 'matematik'};
  static const _gkSlugs = {'tarih', 'cografya', 'vatandaslik', 'guncel'};

  List<NetDevelopmentPoint> buildUnifiedTrend({
    List<PracticeExamModel>? practiceExams,
    List<TgExamModel>? tgExams,
  }) {
    final rows = <_TrendRow>[];

    for (final exam in practiceExams ?? PracticeExamService.instance.allExams) {
      rows.add(
        _TrendRow(
          date: exam.tarih,
          label: exam.denemeAdi,
          totalNet: exam.toplamNet,
          gyNet: exam.genelYetenekNet,
          gkNet: exam.genelKulturNet,
        ),
      );
    }

    for (final exam in tgExams ?? TgExamService.instance.exams) {
      final attempt = exam.myAttempt;
      if (attempt == null || !attempt.isSubmitted) continue;
      final nets = _tgGyGk(attempt);
      rows.add(
        _TrendRow(
          date: exam.endAt,
          label: 'TG · ${exam.title}',
          totalNet: attempt.net,
          gyNet: nets.$1,
          gkNet: nets.$2,
        ),
      );
    }

    rows.sort((a, b) => a.date.compareTo(b.date));
    return rows
        .map(
          (row) => NetDevelopmentPoint(
            label: row.label,
            totalNet: row.totalNet,
            gyNet: row.gyNet,
            gkNet: row.gkNet,
          ),
        )
        .toList();
  }

  (double?, double?) _tgGyGk(TgExamAttemptModel attempt) {
    if (attempt.subjectNets.isEmpty) return (null, null);
    var gy = 0.0;
    var gk = 0.0;
    var hasGy = false;
    var hasGk = false;
    for (final entry in attempt.subjectNets.entries) {
      final slug = entry.key.toLowerCase();
      if (_gySlugs.contains(slug)) {
        gy += entry.value;
        hasGy = true;
      } else if (_gkSlugs.contains(slug)) {
        gk += entry.value;
        hasGk = true;
      }
    }
    return (hasGy ? gy : null, hasGk ? gk : null);
  }
}

class _TrendRow {
  final DateTime date;
  final String label;
  final double totalNet;
  final double? gyNet;
  final double? gkNet;

  const _TrendRow({
    required this.date,
    required this.label,
    required this.totalNet,
    this.gyNet,
    this.gkNet,
  });
}
