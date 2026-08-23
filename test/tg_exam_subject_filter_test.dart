import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/models/question_model.dart';
import 'package:kpss_akademi/utils/tg_exam_subject_filter.dart';
import 'package:kpss_akademi/widgets/tg_exam/tg_section_filter_toggle.dart';

QuestionModel _q({required String id, required String dersAdi}) {
  return QuestionModel(
    id: id,
    dersAdi: dersAdi,
    konuAdi: 'Konu',
    altKonuAdi: 'Alt',
    soruMetni: 'Soru',
    siklar: const {'A': 'a', 'B': 'b', 'C': 'c', 'D': 'd', 'E': 'e'},
    dogruCevap: 'A',
    cozumMetni: 'Çözüm',
    guncellenmeTarihi: DateTime(2024),
  );
}

List<QuestionModel> _fullExamQuestions() {
  return List.generate(120, (i) {
    final key = tgSubjectKeyByIndex(i);
    return _q(id: 'q$i', dersAdi: TgExamSubjectKeys.labelFor(key));
  });
}

void main() {
  group('tgSubjectKeyByIndex', () {
    test('maps ÖSYM block order', () {
      expect(tgSubjectKeyByIndex(0), TgExamSubjectKeys.turkce);
      expect(tgSubjectKeyByIndex(29), TgExamSubjectKeys.turkce);
      expect(tgSubjectKeyByIndex(30), TgExamSubjectKeys.matematik);
      expect(tgSubjectKeyByIndex(59), TgExamSubjectKeys.matematik);
      expect(tgSubjectKeyByIndex(60), TgExamSubjectKeys.tarih);
      expect(tgSubjectKeyByIndex(86), TgExamSubjectKeys.tarih);
      expect(tgSubjectKeyByIndex(87), TgExamSubjectKeys.cografya);
      expect(tgSubjectKeyByIndex(104), TgExamSubjectKeys.cografya);
      expect(tgSubjectKeyByIndex(105), TgExamSubjectKeys.vatandaslik);
      expect(tgSubjectKeyByIndex(113), TgExamSubjectKeys.vatandaslik);
      expect(tgSubjectKeyByIndex(114), TgExamSubjectKeys.guncel);
    });
  });

  group('tgVisibleQuestionIndices', () {
    final questions = _fullExamQuestions();

    test('GY section returns first 60', () {
      final visible = tgVisibleQuestionIndices(
        questions: questions,
        section: TgSectionFilter.gy,
      );
      expect(visible.length, 60);
      expect(visible.first, 0);
      expect(visible.last, 59);
    });

    test('GK Coğrafya filter returns 18 questions', () {
      final visible = tgVisibleQuestionIndices(
        questions: questions,
        section: TgSectionFilter.gk,
        subjectKey: TgExamSubjectKeys.cografya,
      );
      expect(visible.length, 18);
      expect(visible.first, 87);
      expect(visible.last, 104);
    });

    test('GY Matematik filter returns 30 questions', () {
      final visible = tgVisibleQuestionIndices(
        questions: questions,
        section: TgSectionFilter.gy,
        subjectKey: TgExamSubjectKeys.matematik,
      );
      expect(visible.length, 30);
      expect(visible.first, 30);
      expect(visible.last, 59);
    });
  });

  group('tgSubjectCountsInSection', () {
    test('GK counts match ÖSYM distribution', () {
      final counts = tgSubjectCountsInSection(
        questions: _fullExamQuestions(),
        section: TgSectionFilter.gk,
      );
      expect(counts[TgExamSubjectKeys.tarih], 27);
      expect(counts[TgExamSubjectKeys.cografya], 18);
      expect(counts[TgExamSubjectKeys.vatandaslik], 9);
      expect(counts[TgExamSubjectKeys.guncel], 6);
    });
  });
}
