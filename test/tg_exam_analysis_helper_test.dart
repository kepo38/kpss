import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/tg_exam_analysis_helper.dart';

void main() {
  group('TgExamAnalysisHelper.percentileLabel', () {
    test('returns null when ranking or participants missing', () {
      expect(
        TgExamAnalysisHelper.percentileLabel(ranking: null, participantCount: 100),
        isNull,
      );
      expect(
        TgExamAnalysisHelper.percentileLabel(ranking: 5, participantCount: 0),
        isNull,
      );
    });

    test('formats top percentile from rank', () {
      expect(
        TgExamAnalysisHelper.percentileLabel(ranking: 120, participantCount: 1000),
        'Türkiye genelinde üst %12',
      );
      expect(
        TgExamAnalysisHelper.percentileLabel(ranking: 3, participantCount: 1000),
        'Türkiye genelinde üst %0.3',
      );
    });
  });

  group('TgExamAnalysisHelper.fireSubjectLabels', () {
    test('returns lowest net subjects', () {
      final fire = TgExamAnalysisHelper.fireSubjectLabels({
        'tarih': 8.5,
        'cografya': 3.25,
        'vatandaslik': 6.0,
      });
      expect(fire, ['Coğrafya', 'Vatandaşlık']);
    });

    test('merges split turkce slugs under one label', () {
      final fire = TgExamAnalysisHelper.fireSubjectLabels({
        'turkce_anlam': 2.0,
        'turkce_dilbilgisi': 1.5,
        'tarih': 10.0,
      });
      expect(fire.first, 'Türkçe');
      expect(fire.length, 1);
    });
  });
}
