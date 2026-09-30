import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/quiz_result.dart';

void main() {
  QuizResult result({
    required int correct,
    required int wrong,
    required int blank,
    required int total,
  }) {
    return QuizResult(
      correct: correct,
      wrong: wrong,
      blank: blank,
      total: total,
      duration: const Duration(minutes: 12),
    );
  }

  test('KPSS net: 4 yanlış 1 doğruyu götürür', () {
    final r = result(correct: 2, wrong: 3, blank: 18, total: 23);
    expect(r.net, 1.25);
    expect(r.netAccuracy, closeTo(1.25 / 23, 1e-9));
    expect(r.accuracy, closeTo(2 / 23, 1e-9));
  });

  test('netAccuracy uses net over total, not raw correct', () {
    final r = result(correct: 2, wrong: 3, blank: 18, total: 23);
    final rawPct = (r.accuracy * 100).round();
    final netPct = (r.netAccuracy * 100);
    expect(rawPct, 9); // 2/23 ≈ %8.7 → %9
    expect(netPct, closeTo(5.43478, 0.01)); // 1.25/23
  });

  test('negative net is allowed', () {
    final r = result(correct: 1, wrong: 8, blank: 0, total: 9);
    expect(r.net, -1.0);
    expect(r.netAccuracy, closeTo(-1.0 / 9, 1e-9));
  });

  test('empty total yields zero ratios', () {
    final r = result(correct: 0, wrong: 0, blank: 0, total: 0);
    expect(r.net, 0);
    expect(r.accuracy, 0);
    expect(r.netAccuracy, 0);
  });
}
