import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/quiz_result.dart';

void main() {
  test('averageQuestionDuration divides total time by question count', () {
    const result = QuizResult(
      correct: 8,
      wrong: 2,
      blank: 0,
      total: 10,
      duration: Duration(seconds: 500),
    );
    expect(result.averageQuestionDuration, const Duration(seconds: 50));
  });

  test('formatDuration renders readable Turkish units', () {
    expect(
      QuizResult.formatDuration(const Duration(seconds: 42)),
      '42 sn',
    );
    expect(
      QuizResult.formatDuration(const Duration(minutes: 1, seconds: 5)),
      '1 dk 05 sn',
    );
  });
}
