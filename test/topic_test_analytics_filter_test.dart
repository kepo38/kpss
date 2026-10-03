import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/constants/daily_mini_exam_constants.dart';
import 'package:kpss_akademi/models/content_models.dart';
import 'package:kpss_akademi/services/content_bank_service.dart';
import 'package:kpss_akademi/widgets/countdown_widget.dart';

TestAttemptModel _attempt({required String testId}) {
  return TestAttemptModel(
    id: 'a1',
    testId: testId,
    topicId: 'turkce_paragraf',
    kpssType: KpssType.lisans,
    correct: 1,
    wrong: 7,
    blank: 0,
    total: 8,
    duration: Duration.zero,
    completedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('countsTowardTopicTestAnalytics excludes mini, özel and seed tests', () {
    expect(
      ContentBankService.countsTowardTopicTestAnalytics(
        _attempt(testId: 'topic_test_1'),
      ),
      isTrue,
    );
    expect(
      ContentBankService.countsTowardTopicTestAnalytics(
        _attempt(
          testId: '${DailyMiniExamConstants.testIdPrefix}20260101',
        ),
      ),
      isFalse,
    );
    expect(
      ContentBankService.countsTowardTopicTestAnalytics(
        _attempt(testId: 'special_map_1'),
      ),
      isFalse,
    );
    expect(
      ContentBankService.countsTowardTopicTestAnalytics(
        _attempt(testId: 'test_seed_tr_anlam'),
      ),
      isFalse,
    );
  });
}
