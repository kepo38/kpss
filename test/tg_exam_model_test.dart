import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/constants/tg_exam_constants.dart';
import 'package:kpss_akademi/models/tg_exam_models.dart';

TgExamModel _exam({
  required DateTime startAt,
  required DateTime endAt,
  TgExamAttemptModel? attempt,
}) {
  return TgExamModel(
    id: 1,
    title: '[DEMO] TG Deneme · lisans',
    kpssType: 'lisans',
    startAt: startAt,
    endAt: endAt,
    durationMinutes: TgExamConstants.examDurationMinutes,
    questionCount: 120,
    isResultsPublished: false,
    status: attempt == null ? TgExamStatus.active : TgExamStatus.inProgress,
    myAttempt: attempt,
  );
}

void main() {
  test('canEnterLiveExam allows resume until personal timer ends', () {
    final now = DateTime.now();
    final exam = _exam(
      startAt: now.subtract(const Duration(hours: 1)),
      endAt: now.add(const Duration(hours: 4)),
      attempt: const TgExamAttemptModel(
        elapsedSeconds: 3600,
        answers: {'q1': 'A'},
      ),
    );
    expect(exam.hasOpenAttempt, isTrue);
    expect(exam.canEnterLiveExam, isTrue);
    expect(exam.tgQuizRemainingTime(now: now).inMinutes, greaterThan(60));
  });

  test('tgQuizTimeLimitMinutes accounts for elapsed on resume', () {
    final now = DateTime.now();
    final exam = _exam(
      startAt: now.subtract(const Duration(hours: 2)),
      endAt: now.add(const Duration(hours: 4)),
      attempt: const TgExamAttemptModel(elapsedSeconds: 6000),
    );
    final limit = exam.tgQuizTimeLimitMinutes(now: now);
    expect(limit, greaterThan(10));
    expect(limit, lessThanOrEqualTo(TgExamConstants.examDurationMinutes));
  });

  test('canEnterLiveExam blocks when personal timer expired', () {
    final now = DateTime.now();
    final exam = _exam(
      startAt: now.subtract(const Duration(hours: 3)),
      endAt: now.add(const Duration(hours: 1)),
      attempt: TgExamAttemptModel(
        elapsedSeconds: TgExamConstants.examDurationMinutes * 60 + 10,
      ),
    );
    expect(exam.canEnterLiveExam, isFalse);
    expect(exam.tgQuizRemainingTime(now: now), Duration.zero);
  });
}
