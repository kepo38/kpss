import '../models/exam_insight.dart';
import '../models/practice_exam_model.dart';

/// Yayınevi denemesi kaydı — geçen ay kıyası ve konu önerisi.
class ExamInsightService {
  ExamInsightService._();
  static final ExamInsightService instance = ExamInsightService._();

  static const _topicBySubject = <String, String>{
    'Vatandaşlık': '1982 Anayasası Yargı Bölümü',
    'Tarih': 'Atatürk İnkılapları',
    'Coğrafya': 'Türkiye\'nin Coğrafi Bölgeleri',
    'Türkçe': 'Paragraf',
    'Matematik': 'Problemler',
  };

  /// [allExams] güncel kayıt dahil tüm denemeler (en yeni başta olabilir).
  ExamInsight? buildForNewExam(
    PracticeExamModel exam,
    List<PracticeExamModel> allExams,
  ) {
    if (exam.isInAppGenerated) return null;

    final baseline = _baselineExams(exam, allExams);
    if (baseline.isEmpty) return null;

    final prevAvgTotal = _averageTotalNet(baseline);
    final netDelta = (exam.toplamNet - prevAvgTotal).round();

    final decline = _largestSubjectDecline(exam, baseline);
    final examLabel = '${exam.yayinEvi} ${exam.denemeAdi}'.trim();
    final message = _composeMessage(
      examLabel: examLabel,
      netDelta: netDelta,
      decliningSubject: decline?.subject,
      recommendedTopic: decline?.topic,
    );

    return ExamInsight(
      examLabel: examLabel,
      netDelta: netDelta,
      decliningSubject: decline?.subject,
      recommendedTopic: decline?.topic,
      message: message,
    );
  }

  List<PracticeExamModel> _baselineExams(
    PracticeExamModel exam,
    List<PracticeExamModel> allExams,
  ) {
    final prevStart = _previousMonthStart(exam.tarih);
    final prevEnd = _previousMonthEnd(exam.tarih);

    var pool = allExams.where((e) {
      if (e.id == exam.id) return false;
      if (e.isInAppGenerated) return false;
      if (e.tarih.isBefore(prevStart) || e.tarih.isAfter(prevEnd)) return false;
      return true;
    }).toList();

    final samePublisher =
        pool.where((e) => e.yayinEvi == exam.yayinEvi).toList();
    if (samePublisher.isNotEmpty) return samePublisher;

    return pool;
  }

  DateTime _previousMonthStart(DateTime date) {
    final firstThisMonth = DateTime(date.year, date.month, 1);
    final lastPrev = firstThisMonth.subtract(const Duration(days: 1));
    return DateTime(lastPrev.year, lastPrev.month, 1);
  }

  DateTime _previousMonthEnd(DateTime date) {
    final firstThisMonth = DateTime(date.year, date.month, 1);
    return firstThisMonth.subtract(const Duration(days: 1));
  }

  double _averageTotalNet(List<PracticeExamModel> exams) {
    if (exams.isEmpty) return 0;
    return exams.map((e) => e.toplamNet).reduce((a, b) => a + b) / exams.length;
  }

  Map<String, double> _averageSubjectNets(List<PracticeExamModel> exams) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final exam in exams) {
      exam.dersSonuclari.forEach((ders, sonuc) {
        sums[ders] = (sums[ders] ?? 0) + sonuc.net;
        counts[ders] = (counts[ders] ?? 0) + 1;
      });
    }
    return {
      for (final ders in sums.keys)
        ders: sums[ders]! / counts[ders]!,
    };
  }

  ({String subject, String topic, double drop})? _largestSubjectDecline(
    PracticeExamModel exam,
    List<PracticeExamModel> baseline,
  ) {
    final baselineAvg = _averageSubjectNets(baseline);
    ({String subject, String topic, double drop})? worst;

    for (final entry in exam.dersSonuclari.entries) {
      final ders = entry.key;
      final prev = baselineAvg[ders];
      if (prev == null) continue;
      final drop = prev - entry.value.net;
      if (drop < 0.25) continue;

      final topic = _topicBySubject[ders];
      if (topic == null) continue;

      if (worst == null || drop > worst.drop) {
        worst = (subject: ders, topic: topic, drop: drop);
      }
    }
    return worst;
  }

  String _composeMessage({
    required String examLabel,
    required int netDelta,
    required String? decliningSubject,
    required String? recommendedTopic,
  }) {
    final buffer = StringBuffer('$examLabel denemesinde ');

    if (netDelta > 0) {
      buffer.write('netlerin geçen aya göre $netDelta net artmış');
    } else if (netDelta < 0) {
      buffer.write('netlerin geçen aya göre ${netDelta.abs()} net azalmış');
    } else {
      buffer.write('netlerin geçen aya göre benzer seviyede');
    }

    if (decliningSubject != null && recommendedTopic != null) {
      buffer.write(' ama ${_subjectLocative(decliningSubject)} düşüş var.');
      buffer.write(' Tavsiye edilen konu tekrarı: $recommendedTopic.');
    } else {
      buffer.write('.');
    }

    return buffer.toString();
  }

  String _subjectLocative(String ders) {
    switch (ders) {
      case 'Vatandaşlık':
        return 'Vatandaşlıkta';
      case 'Tarih':
        return 'Tarihte';
      case 'Coğrafya':
        return 'Coğrafyada';
      case 'Türkçe':
        return 'Türkçede';
      case 'Matematik':
        return 'Matematikte';
      default:
        return '$ders\'ta';
    }
  }
}
