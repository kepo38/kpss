import '../constants/tg_exam_constants.dart';
import '../models/question_model.dart';
import '../widgets/tg_exam/tg_section_filter_toggle.dart';

/// TG deneme ders anahtarları — GY / GK alt filtreleri.
abstract final class TgExamSubjectKeys {
  static const turkce = 'turkce';
  static const matematik = 'matematik';
  static const tarih = 'tarih';
  static const cografya = 'cografya';
  static const vatandaslik = 'vatandaslik';
  static const guncel = 'guncel';

  static const gy = [turkce, matematik];
  static const gk = [tarih, cografya, vatandaslik, guncel];

  static const labels = {
    turkce: 'Türkçe',
    matematik: 'Matematik',
    tarih: 'Tarih',
    cografya: 'Coğrafya',
    vatandaslik: 'Vatandaşlık',
    guncel: 'Güncel',
  };

  static List<String> forSection(TgSectionFilter section) {
    switch (section) {
      case TgSectionFilter.gy:
        return gy;
      case TgSectionFilter.gk:
        return gk;
      case TgSectionFilter.all:
        return const [];
    }
  }

  static String labelFor(String key) => labels[key] ?? key;
}

/// `dersAdi` veya ÖSYM sıra indeksinden ders anahtarı.
String tgSubjectKeyForQuestion(QuestionModel question, int index) {
  final fromName = _subjectKeyFromDersAdi(question.dersAdi);
  if (fromName != null) return fromName;
  return tgSubjectKeyByIndex(index);
}

String? _subjectKeyFromDersAdi(String dersAdi) {
  final d = _normalizeTr(dersAdi);
  if (d.contains('turk')) return TgExamSubjectKeys.turkce;
  if (d.contains('matematik')) return TgExamSubjectKeys.matematik;
  if (d.contains('tarih')) return TgExamSubjectKeys.tarih;
  if (d.contains('cograf')) return TgExamSubjectKeys.cografya;
  if (d.contains('vatandas')) return TgExamSubjectKeys.vatandaslik;
  if (d.contains('guncel')) return TgExamSubjectKeys.guncel;
  return null;
}

String _normalizeTr(String value) {
  return value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

/// ÖSYM TG tam deneme sırası (30+30+27+18+9+6).
String tgSubjectKeyByIndex(int index) {
  if (index < 30) return TgExamSubjectKeys.turkce;
  if (index < TgExamConstants.gyQuestionCount) {
    return TgExamSubjectKeys.matematik;
  }
  if (index < 87) return TgExamSubjectKeys.tarih;
  if (index < 105) return TgExamSubjectKeys.cografya;
  if (index < 114) return TgExamSubjectKeys.vatandaslik;
  return TgExamSubjectKeys.guncel;
}

List<int> tgSectionIndices({
  required TgSectionFilter section,
  required int total,
}) {
  switch (section) {
    case TgSectionFilter.gy:
      final end = TgExamConstants.gyQuestionCount.clamp(0, total);
      return List.generate(end, (i) => i);
    case TgSectionFilter.gk:
      final start = TgExamConstants.gkStartIndex.clamp(0, total);
      if (start >= total) return const [];
      return List.generate(total - start, (i) => i + start);
    case TgSectionFilter.all:
      return List.generate(total, (i) => i);
  }
}

List<int> tgVisibleQuestionIndices({
  required List<QuestionModel> questions,
  required TgSectionFilter section,
  String? subjectKey,
}) {
  final sectionIndices = tgSectionIndices(
    section: section,
    total: questions.length,
  );
  if (subjectKey == null || subjectKey.isEmpty) {
    return sectionIndices;
  }
  return sectionIndices
      .where(
        (i) => tgSubjectKeyForQuestion(questions[i], i) == subjectKey,
      )
      .toList(growable: false);
}

Map<String, int> tgSubjectCountsInSection({
  required List<QuestionModel> questions,
  required TgSectionFilter section,
}) {
  final counts = <String, int>{};
  for (final i in tgSectionIndices(section: section, total: questions.length)) {
    final key = tgSubjectKeyForQuestion(questions[i], i);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}
