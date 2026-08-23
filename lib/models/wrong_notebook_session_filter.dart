import 'question_model.dart';
import '../data/kpss_curriculum.dart';
import '../services/last_study_session_service.dart';
import '../widgets/countdown_widget.dart';

/// Az önce biten testteki yanlışlar — Yanlış Defteri oturum filtresi.
class WrongNotebookSessionFilter {
  final String sessionTitle;
  final String? testId;
  final List<String> questionIds;
  final List<QuestionModel> prefetchedQuestions;

  const WrongNotebookSessionFilter({
    required this.sessionTitle,
    required this.questionIds,
    this.testId,
    this.prefetchedQuestions = const [],
  });

  int get questionCount => questionIds.length;

  /// Konu testi sonucundan oturum filtresi üretir.
  factory WrongNotebookSessionFilter.fromTopicQuiz({
    required QuizResumeMeta meta,
    required String fallbackTitle,
    required List<String> wrongQuestionIds,
    required List<QuestionModel> allQuestions,
    String? testId,
  }) {
    final wrongSet = wrongQuestionIds.toSet();
    final prefetched =
        allQuestions.where((q) => wrongSet.contains(q.id)).toList();
    final count = wrongQuestionIds.length;

    final subject = KpssCurriculum.findSubject(meta.kpssType, meta.subjectId);
    final topic = KpssCurriculum.findTopic(meta.kpssType, meta.topicId);

    String title;
    if (subject != null && topic != null) {
      title = '${subject.name} · ${topic.name} Yanlışları ($count Soru)';
    } else if (subject != null) {
      title = '${subject.name} Konu Testi Yanlışları ($count Soru)';
    } else {
      title = '$fallbackTitle Yanlışları ($count Soru)';
    }

    return WrongNotebookSessionFilter(
      sessionTitle: title,
      testId: testId ?? meta.testId,
      questionIds: List<String>.from(wrongQuestionIds),
      prefetchedQuestions: prefetched,
    );
  }
}
