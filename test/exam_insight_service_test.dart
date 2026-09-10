import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/practice_exam_model.dart';
import 'package:kpss_akademi/services/exam_insight_service.dart';

void main() {
  group('ExamInsightService', () {
    test('builds month-over-month insight with subject decline', () {
      final prevMonth = DateTime(2026, 7, 15);
      final thisMonth = DateTime(2026, 8, 20);

      final baseline = PracticeExamModel(
        id: 'prev',
        denemeAdi: 'TG-2',
        yayinEvi: 'Yargı',
        tarih: prevMonth,
        dersSonuclari: const {
          'Türkçe': DersSonuc(dogru: 22, yanlis: 6, bos: 2),
          'Matematik': DersSonuc(dogru: 12, yanlis: 8, bos: 10),
          'Tarih': DersSonuc(dogru: 18, yanlis: 4, bos: 5),
          'Coğrafya': DersSonuc(dogru: 10, yanlis: 3, bos: 5),
          'Vatandaşlık': DersSonuc(dogru: 12, yanlis: 1, bos: 2),
        },
      );

      final current = PracticeExamModel(
        id: 'cur',
        denemeAdi: 'TG-3',
        yayinEvi: 'Yargı',
        tarih: thisMonth,
        dersSonuclari: const {
          'Türkçe': DersSonuc(dogru: 24, yanlis: 4, bos: 2),
          'Matematik': DersSonuc(dogru: 14, yanlis: 7, bos: 9),
          'Tarih': DersSonuc(dogru: 19, yanlis: 3, bos: 5),
          'Coğrafya': DersSonuc(dogru: 11, yanlis: 2, bos: 5),
          'Vatandaşlık': DersSonuc(dogru: 9, yanlis: 3, bos: 3),
        },
      );

      final insight = ExamInsightService.instance.buildForNewExam(
        current,
        [current, baseline],
      );

      expect(insight, isNotNull);
      expect(
        insight!.message,
        'Yargı TG-3 denemesinde netlerin geçen aya göre 4 net artmış '
        'ama Vatandaşlıkta düşüş var. '
        'Tavsiye edilen konu tekrarı: 1982 Anayasası Yargı Bölümü.',
      );
    });

    test('returns null without previous month baseline', () {
      final current = PracticeExamModel(
        id: 'only',
        denemeAdi: 'TG-1',
        yayinEvi: 'Yargı',
        tarih: DateTime(2026, 8, 1),
        dersSonuclari: const {
          'Türkçe': DersSonuc(dogru: 20, yanlis: 5, bos: 5),
        },
      );

      final insight = ExamInsightService.instance.buildForNewExam(
        current,
        [current],
      );

      expect(insight, isNull);
    });
  });
}
