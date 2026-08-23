import '../models/tg_exam_models.dart';

/// TG deneme sonrası yüzdelik dilim ve ders bazlı fire analizi.
class TgExamAnalysisHelper {
  TgExamAnalysisHelper._();

  static const proUpsellSubtitle =
      'Türkiye geneli yüzdelik dilimini ve hangi konulardan fire verdiğini '
      'görmek için Pro\'ya geç';

  /// Sıralamadan üst yüzdelik dilim etiketi (ör. "Türkiye genelinde üst %12").
  static String? percentileLabel({
    required int? ranking,
    required int participantCount,
  }) {
    if (ranking == null || participantCount <= 0) return null;
    final topPercent =
        (ranking / participantCount * 100).clamp(0.1, 100.0).toDouble();
    if (topPercent <= 1.0) {
      return 'Türkiye genelinde üst %${topPercent.toStringAsFixed(1)}';
    }
    return 'Türkiye genelinde üst %${topPercent.round()}';
  }

  /// En düşük netli dersler — kullanıcıya "fire" olarak gösterilir.
  static List<String> fireSubjectLabels(
    Map<String, double> subjectNets, {
    int maxCount = 2,
  }) {
    if (subjectNets.isEmpty || maxCount <= 0) return const [];

    final byLabel = <String, double>{};
    for (final entry in subjectNets.entries) {
      final label = tgExamSubjectLabel(entry.key);
      byLabel[label] = (byLabel[label] ?? 0) + entry.value;
    }

    final sorted = byLabel.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.take(maxCount).map((e) => e.key).toList(growable: false);
  }
}
