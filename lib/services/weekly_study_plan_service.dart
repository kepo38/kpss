import '../data/kpss_curriculum.dart';
import '../models/subject_performance.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';
import 'performance_summary_service.dart';

/// Haftalık çalışma planı günü.
class WeeklyPlanDay {
  final DateTime date;
  final String dayLabel;
  final bool isToday;
  final List<String> tasks;

  const WeeklyPlanDay({
    required this.date,
    required this.dayLabel,
    required this.isToday,
    required this.tasks,
  });
}

/// 7 günlük stratejik rota — bugün ücretsiz, ilerisi Pro.
class WeeklyStudyPlanService {
  WeeklyStudyPlanService._();
  static final WeeklyStudyPlanService instance = WeeklyStudyPlanService._();

  static const _missionIds = [
    'turkce',
    'matematik',
    'tarih',
    'cografya',
    'vatandaslik',
  ];

  List<WeeklyPlanDay> buildPlan(KpssType type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bank = ContentBankService.instance;
    final weak = _globalWeakTopics(type);
    final subjects = KpssCurriculum.subjectsFor(type)
        .where((s) => _missionIds.contains(s.id))
        .toList();

    return List.generate(7, (i) {
      final date = today.add(Duration(days: i));
      final tasks = <String>[];

      if (i == 0) {
        for (final s in subjects) {
          if (bank.dailyCompletedTestsForSubject(type, s.id) == 0) {
            tasks.add('${s.name} — günlük konu testi');
          }
        }
        if (tasks.isEmpty) {
          tasks.add('Günlük 5 görev tamam — zayıf konu tekrarı');
        }
        if (weak.isNotEmpty) {
          tasks.add('Zayıf konu: ${weak.first.topicName}');
        }
      } else {
        final subject = subjects[i % subjects.length];
        final weakTopic = weak.isNotEmpty
            ? weak[(i - 1) % weak.length].topicName
            : '${subject.name} tekrar';
        tasks.addAll([
          '${subject.name} konu testi',
          weakTopic,
          if (i == 6) 'Haftalık mini deneme simülasyonu',
        ]);
      }

      return WeeklyPlanDay(
        date: date,
        dayLabel: _dayLabel(date, today),
        isToday: i == 0,
        tasks: tasks,
      );
    });
  }

  List<WeakTopicStat> _globalWeakTopics(KpssType type) {
    final all = <WeakTopicStat>[];
    for (final s in PerformanceSummaryService.instance.subjectBreakdown(type)) {
      all.addAll(s.topWeakTopics);
    }
    all.sort((a, b) => b.wrongCount.compareTo(a.wrongCount));
    return all;
  }

  String _dayLabel(DateTime date, DateTime today) {
    if (date == today) return 'Bugün';
    if (date == today.add(const Duration(days: 1))) return 'Yarın';
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return names[date.weekday - 1];
  }
}
