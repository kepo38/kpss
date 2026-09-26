import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/data/kpss_curriculum.dart';
import 'package:kpss_akademi/models/wrong_notebook_session_filter.dart';
import 'package:kpss_akademi/services/last_study_session_service.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

void main() {
  group('WrongNotebookSessionFilter.fromTopicQuiz', () {
    const meta = QuizResumeMeta(
      testId: 'test_1',
      kpssType: KpssType.lisans,
      subjectId: 'turkce',
      topicId: 'turkce_anlam',
    );

    test('builds subject and topic title', () {
      final filter = WrongNotebookSessionFilter.fromTopicQuiz(
        meta: meta,
        fallbackTitle: 'Test 1',
        wrongQuestionIds: const ['q1', 'q2', 'q3'],
        allQuestions: const [],
      );

      final subject = KpssCurriculum.findSubject(KpssType.lisans, 'turkce');
      final topic =
          KpssCurriculum.findTopic(KpssType.lisans, 'turkce_anlam');
      expect(subject, isNotNull);
      expect(topic, isNotNull);
      expect(
        filter.sessionTitle,
        '${subject!.name} · ${topic!.name} Yanlışları (3 Soru)',
      );
      expect(filter.testId, 'test_1');
      expect(filter.questionIds, ['q1', 'q2', 'q3']);
    });

    test('falls back to test title when curriculum missing', () {
      const unknownMeta = QuizResumeMeta(
        testId: 'test_x',
        kpssType: KpssType.lisans,
        subjectId: 'unknown_subject',
        topicId: 'unknown_topic',
      );

      final filter = WrongNotebookSessionFilter.fromTopicQuiz(
        meta: unknownMeta,
        fallbackTitle: 'Paragraf Testi',
        wrongQuestionIds: const ['q9'],
        allQuestions: const [],
      );

      expect(filter.sessionTitle, 'Paragraf Testi Yanlışları (1 Soru)');
    });
  });
}
