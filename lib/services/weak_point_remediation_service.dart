import '../data/kpss_curriculum.dart';
import '../models/question_model.dart';
import '../models/subject_performance.dart';
import '../widgets/countdown_widget.dart';
import 'content_bank_service.dart';
import 'performance_summary_service.dart';
import 'question_fetch_service.dart';

/// En çok yanlış yapılan 3 konudan telafi testi — Pro.
class WeakPointRemediationService {
  WeakPointRemediationService._();
  static final WeakPointRemediationService instance =
      WeakPointRemediationService._();

  static const packSize = 15;

  List<WeakTopicStat> topWeakTopics(
    KpssType type, {
    int limit = 3,
    String? subjectId,
  }) {
    if (subjectId != null) {
      final match = PerformanceSummaryService.instance
          .subjectBreakdown(type)
          .where((s) => s.subjectId == subjectId)
          .toList();
      if (match.isEmpty) return const [];
      return match.first.topWeakTopics.take(limit).toList();
    }

    final all = <WeakTopicStat>[];
    for (final s in PerformanceSummaryService.instance.subjectBreakdown(type)) {
      all.addAll(s.topWeakTopics);
    }
    all.sort((a, b) => b.wrongCount.compareTo(a.wrongCount));
    return all.take(limit).toList();
  }

  /// En çok yanlış 3 konudan telafi soru kimlikleri (Akıllı Tekrar havuzu).
  List<String> remediationQuestionIds(
    KpssType type, {
    String? subjectId,
  }) {
    final weak = topWeakTopics(type, subjectId: subjectId);
    if (weak.isEmpty) return const [];

    final bank = ContentBankService.instance;
    final topicNames = weak.map((w) => w.topicName).toSet();
    final wrongBodies = bank.questionsByIds(bank.wrongQuestionIds.toList());

    final fromWrong = wrongBodies
        .where((q) => topicNames.contains(q.konuAdi))
        .map((q) => q.id)
        .toList();

    final fromBank = <String>[];
    for (final subject in KpssCurriculum.subjectsFor(type)) {
      if (subjectId != null && subject.id != subjectId) continue;
      for (final topic in subject.topics) {
        if (!topicNames.contains(topic.name)) continue;
        for (final test in bank.testsForTopic(type, topic.id)) {
          fromBank.addAll(test.questionIds);
        }
      }
    }

    return <String>{...fromWrong, ...fromBank}.take(packSize).toList();
  }

  Future<List<QuestionModel>> fetchRemediationPack(
    KpssType type, {
    String? subjectId,
  }) async {
    final ids = remediationQuestionIds(type, subjectId: subjectId);
    if (ids.isEmpty) return const [];

    final fetched = await QuestionFetchService.instance.fetchByIds(ids);
    if (fetched.isNotEmpty) return fetched;
    return ContentBankService.instance.questionsByIds(ids);
  }
}
