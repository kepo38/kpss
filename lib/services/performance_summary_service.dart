import '../data/kpss_curriculum.dart';
import '../models/subject_performance.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';

/// Gelişim sekmesi: ders bazlı performans (yalnızca konu testleri).
class PerformanceSummaryService {
  PerformanceSummaryService._();
  static final PerformanceSummaryService instance =
      PerformanceSummaryService._();

  List<SubjectPerformance> subjectBreakdown(KpssType type) {
    final bank = ContentBankService.instance;
    final subjects = KpssCurriculum.subjectsFor(type);

    return subjects.map((subject) {
      final topicIds = {for (final t in subject.topics) t.id};
      final topicNameById = {for (final t in subject.topics) t.id: t.name};

      var correct = 0;
      var wrong = 0;
      var blank = 0;
      var solved = 0;
      final weakFromTests = <String, int>{};

      for (final a in bank.attemptsForType(type)) {
        if (!ContentBankService.countsTowardDailyHomework(a)) continue;
        if (!topicIds.contains(a.topicId)) continue;
        correct += a.correct;
        wrong += a.wrong;
        blank += a.blank;
        solved += a.total;
        final name = topicNameById[a.topicId];
        if (name != null && a.wrong > 0) {
          weakFromTests[name] = (weakFromTests[name] ?? 0) + a.wrong;
        }
      }

      final topWeak = weakFromTests.entries
          .where((e) => e.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return SubjectPerformance(
        subjectId: subject.id,
        subjectName: subject.name,
        solved: solved,
        correct: correct,
        wrong: wrong,
        blank: blank,
        topWeakTopics: topWeak
            .take(3)
            .map(
              (e) => WeakTopicStat(topicName: e.key, wrongCount: e.value),
            )
            .toList(),
      );
    }).toList();
  }

  int totalQuestionsInBank(KpssType type) {
    final bank = ContentBankService.instance;
    final ids = <String>{};
    for (final subject in KpssCurriculum.subjectsFor(type)) {
      for (final topic in subject.topics) {
        for (final test in bank.testsForTopic(type, topic.id)) {
          ids.addAll(test.questionIds);
        }
      }
    }
    return ids.length;
  }

  OverallPerformance overall(KpssType type) {
    final list = subjectBreakdown(type);
    final solved = list.fold(0, (s, e) => s + e.solved);
    final correct = list.fold(0, (s, e) => s + e.correct);
    final wrong = list.fold(0, (s, e) => s + e.wrong);
    final blank = list.fold(0, (s, e) => s + e.blank);
    return OverallPerformance(
      solved: solved,
      correct: correct,
      wrong: wrong,
      blank: blank,
      totalQuestions: totalQuestionsInBank(type),
    );
  }

  SubjectAttemptHistory subjectAttemptHistory(
    KpssType type,
    String subjectId,
  ) {
    final bank = ContentBankService.instance;
    final subject = KpssCurriculum.findSubject(type, subjectId);
    if (subject == null) {
      return SubjectAttemptHistory(
        subjectId: subjectId,
        subjectName: subjectId,
        topics: const [],
      );
    }

    final topicNameById = {for (final t in subject.topics) t.id: t.name};
    final topicIds = topicNameById.keys.toSet();
    final byTopic = <String, List<AttemptDetail>>{};

    for (final kpssType in KpssType.values) {
      for (final a in bank.attemptsForType(kpssType)) {
        if (!ContentBankService.countsTowardDailyHomework(a)) continue;
        if (!topicIds.contains(a.topicId)) continue;
        final testTitle = bank.testById(a.testId)?.title ?? 'Test';
        final topicName = topicNameById[a.topicId] ?? a.topicId;
        byTopic.putIfAbsent(a.topicId, () => []).add(
              AttemptDetail(
                testTitle: testTitle,
                topicName: topicName,
                correct: a.correct,
                wrong: a.wrong,
                blank: a.blank,
                total: a.total,
                completedAt: a.completedAt,
                duration: a.duration,
              ),
            );
      }
    }

    final groups = byTopic.entries.map((e) {
      final attempts = e.value
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return TopicAttemptGroup(
        topicId: e.key,
        topicName: topicNameById[e.key] ?? e.key,
        attempts: attempts,
      );
    }).toList()
      ..sort((a, b) {
        final aLast = a.lastAttemptAt;
        final bLast = b.lastAttemptAt;
        if (aLast == null && bLast == null) return 0;
        if (aLast == null) return 1;
        if (bLast == null) return -1;
        return bLast.compareTo(aLast);
      });

    return SubjectAttemptHistory(
      subjectId: subject.id,
      subjectName: subject.name,
      topics: groups,
    );
  }
}
