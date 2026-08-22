import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/practice_exam_model.dart';
import 'package:kpss_akademi/models/tg_exam_models.dart';
import 'package:kpss_akademi/services/exam_trend_service.dart';

void main() {
  group('ExamTrendService', () {
    test('merges practice and submitted TG attempts chronologically', () {
      final practice = [
        PracticeExamModel(
          id: 'p1',
          denemeAdi: 'Paraf Deneme 1',
          yayinEvi: 'Paraf',
          tarih: DateTime(2026, 1, 10),
          dersSonuclari: const {
            'Türkçe': DersSonuc(dogru: 20, yanlis: 5, bos: 5),
            'Matematik': DersSonuc(dogru: 15, yanlis: 10, bos: 5),
            'Tarih': DersSonuc(dogru: 18, yanlis: 5, bos: 4),
          },
        ),
      ];

      final tg = [
        TgExamModel(
          id: 1,
          title: 'TG Ocak',
          kpssType: 'lisans',
          startAt: DateTime(2026, 1, 5),
          endAt: DateTime(2026, 1, 15),
          durationMinutes: 130,
          questionCount: 120,
          isResultsPublished: true,
          status: TgExamStatus.results,
          myAttempt: const TgExamAttemptModel(
            isSubmitted: true,
            net: 72,
            subjectNets: {
              'turkce': 15,
              'matematik': 17,
              'tarih': 20,
              'cografya': 20,
            },
          ),
        ),
      ];

      final points = ExamTrendService.instance.buildUnifiedTrend(
        practiceExams: practice,
        tgExams: tg,
      );

      expect(points, hasLength(2));
      expect(points.first.label, contains('Paraf'));
      expect(points.last.label, contains('TG'));
      expect(points.last.totalNet, 72);
      expect(points.last.gyNet, 32);
      expect(points.last.gkNet, 40);
    });

    test('skips TG attempts that are not submitted', () {
      final tg = [
        TgExamModel(
          id: 2,
          title: 'TG Şubat',
          kpssType: 'lisans',
          startAt: DateTime(2026, 2, 1),
          endAt: DateTime(2026, 2, 10),
          durationMinutes: 130,
          questionCount: 120,
          isResultsPublished: false,
          status: TgExamStatus.active,
          myAttempt: const TgExamAttemptModel(
            isSubmitted: false,
            net: 0,
          ),
        ),
      ];

      final points = ExamTrendService.instance.buildUnifiedTrend(
        practiceExams: const [],
        tgExams: tg,
      );

      expect(points, isEmpty);
    });
  });
}
