import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/question_error_report_service.dart';

void main() {
  test('premium error reports require three completed tests', () {
    expect(
      QuestionErrorReportService.minTestsRequiredFor(isPremium: true),
      3,
    );
    expect(
      QuestionErrorReportService.minTestsRequiredFor(isPremium: false),
      5,
    );
  });

  test('warning text uses the required count', () {
    expect(
      QuestionErrorReportService.testsRequiredWarning(
        completed: 1,
        required: 3,
      ),
      contains('En az 3 test'),
    );
    expect(
      QuestionErrorReportService.testsRequiredWarning(
        completed: 1,
        required: 3,
      ),
      contains('1/3'),
    );
  });
}
