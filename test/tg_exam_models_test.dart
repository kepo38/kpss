import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/constants/tg_exam_constants.dart';
import 'package:kpss_akademi/models/tg_exam_models.dart';

void main() {
  group('TgExamModel.effectiveCountdown', () {
    TgExamModel exam({
      required DateTime startAt,
      required DateTime endAt,
      int durationMinutes = TgExamConstants.examDurationMinutes,
    }) {
      return TgExamModel(
        id: 1,
        title: 'Test',
        kpssType: 'lisans',
        startAt: startAt,
        endAt: endAt,
        durationMinutes: durationMinutes,
        questionCount: 120,
        isResultsPublished: false,
        status: TgExamStatus.active,
      );
    }

    test('uses session cap when window is wide', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final model = exam(
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 5)),
      );
      expect(model.effectiveCountdownMinutes(now: now), 130);
    });

    test('caps at time until endAt when window is narrow', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final model = exam(
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(minutes: 25)),
      );
      expect(model.effectiveCountdownMinutes(now: now), 25);
    });

    test('returns zero when window closed', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      final model = exam(
        startAt: now.subtract(const Duration(hours: 3)),
        endAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(model.effectiveCountdownMinutes(now: now), 0);
    });
  });
}
