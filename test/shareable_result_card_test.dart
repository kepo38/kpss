import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/constants/brand_constants.dart';
import 'package:kpss_akademi/models/quiz_result.dart';
import 'package:kpss_akademi/widgets/shareable_result_card.dart';

void main() {
  test('share text includes net and score breakdown', () {
    const result = QuizResult(
      correct: 8,
      wrong: 2,
      blank: 0,
      total: 10,
      duration: Duration(minutes: 12),
      wrongQuestionIds: ['a', 'b'],
      correctQuestionIds: ['c'],
    );
    final text = ResultCardShare.shareText('Türkçe Test 1', result);
    expect(text, contains('${BrandConstants.appName} · Türkçe Test 1'));
    expect(text, contains('Net 7.50'));
    expect(text, contains('%80 başarı'));
    expect(text, contains('Doğru 8'));
    expect(text, contains('Yanlış 2'));
    expect(text, contains('#KPSSOdak'));
  });
}
